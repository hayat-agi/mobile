import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'earthquake_config.dart';
import 'earthquake_debug_info.dart';
import 'earthquake_state.dart';
import 'replay_accelerometer_stream.dart';
import 'algorithms/feature_extractor.dart';
import 'algorithms/sta_lta.dart';
import 'algorithms/stationarity_detector.dart';
import '../ble/sensor_packet.dart';

/// Singleton service that monitors the phone accelerometer for seismic activity.
///
/// Detection pipeline:
///   Pre-filter: Stationarity gate (phone must be still)
///   Pre-filter: Gyroscope veto (no rotational motion = not hand-held)
///   Layer 1: STA/LTA ratio trigger (continuous, low-cost, includes LTA stability guard)
///   Layer 2: IQR + ZC + CAV + kurtosis feature analysis (only on Layer 1 trigger)
///
/// Follows the same singleton + ValueNotifier pattern as BleService.
class EarthquakeDetectionService {
  static final EarthquakeDetectionService _instance =
      EarthquakeDetectionService._internal();
  factory EarthquakeDetectionService() => _instance;
  EarthquakeDetectionService._internal();

  // ── Algorithm instances ──────────────────────────────────────────────────
  final _staLta = StaLtaCalculator();
  final _stationarity = StationarityDetector();

  /// Sliding buffer of raw net-acceleration magnitudes for feature extraction.
  final _featureBuffer = Queue<double>();

  // ── Reactive state (ValueNotifier for plain Flutter widgets) ─────────────

  /// Current lifecycle state of the earthquake monitor.
  final ValueNotifier<EarthquakeMonitorState> monitorState =
      ValueNotifier(EarthquakeMonitorState.idle);

  /// The most recent confirmed detection event, or null if none yet.
  final ValueNotifier<EarthquakeEvent?> lastEvent = ValueNotifier(null);

  /// Stream that emits an [EarthquakeEvent] each time a detection is confirmed.
  /// Widgets / pages subscribe to this to react (show dialog, navigate, etc.).
  Stream<EarthquakeEvent> get detectionStream => _detectionController.stream;
  final _detectionController = StreamController<EarthquakeEvent>.broadcast();

  /// Stream that emits a debug snapshot every time the feature layer is
  /// evaluated or blocked. Subscribe in debug/test pages to see live values.
  Stream<EarthquakeDebugInfo> get debugStream => _debugController.stream;
  final _debugController = StreamController<EarthquakeDebugInfo>.broadcast();

  /// When true, feature extraction runs even when blocked by stationarity or
  /// gyroscope pre-filters. The result is emitted on [debugStream] but does
  /// NOT trigger detection. Use this to capture hand-shake feature values.
  bool debugForceFeatures = false;

  // ── Debug / diagnostics ──────────────────────────────────────────────────

  /// Current STA/LTA ratio — useful for live debug display.
  final ValueNotifier<double> currentRatio = ValueNotifier(0.0);

  /// True while a CSV replay is running.
  final ValueNotifier<bool> isReplaying = ValueNotifier(false);

  // ── Internal state ───────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _replaySubscription;

  /// Active subscription to an external [SensorPacket] stream (ESP32 MPU-6050).
  /// Non-null only while [startExternal] is active.
  StreamSubscription<SensorPacket>? _externalSubscription;
  Timer? _cooldownTimer;
  bool _inCooldown = false;
  bool get _usingExternalStream => _externalSubscription != null;
  bool get isUsingExternalStream => _externalSubscription != null;

  /// Rolling window of booleans: was STA/LTA above threshold for each sample?
  /// Maintained at a fixed size of [EarthquakeConfig.triggerWindowSamples].
  final Queue<bool> _triggerWindow = Queue<bool>();

  /// Running count of `true` entries in [_triggerWindow] — avoids O(n) scan.
  int _triggerWindowAboveCount = 0;

  // ── Gyroscope tracking ───────────────────────────────────────────────────
  final Queue<bool> _gyroAboveWindow = Queue<bool>();
  int _gyroAboveCount = 0;
  double _lastGyroMagnitude = 0.0;

  // ── Post-trigger collection ──────────────────────────────────────────────
  bool _collectingPostTrigger = false;
  int _postTriggerSampleCount = 0;

  bool _disposed = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Start accelerometer monitoring. Safe to call multiple times (idempotent).
  void start() {
    if (_usingExternalStream) return;

    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    // Reset pipeline state so stale data from a prior session never bleeds in.
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();
    _resetTriggerWindow();
    _resetGyroWindow();
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;

    _sensorSubscription = accelerometerEventStream(
      samplingPeriod: EarthquakeConfig.samplingInterval,
    ).listen(
      _onSample,
      onError: (Object e) {
        debugPrint('EarthquakeDetectionService: sensor error: $e');
        stop();
      },
      cancelOnError: false,
    );

    // Subscribe to gyroscope for rotation veto
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: EarthquakeConfig.samplingInterval,
    ).listen(
      _onGyroSample,
      onError: (Object e) {
        debugPrint('EarthquakeDetectionService: gyro error: $e');
        // Gyro is optional — continue without it
      },
      cancelOnError: false,
    );

    monitorState.value = EarthquakeMonitorState.monitoring;
    debugPrint('EarthquakeDetectionService: started');
  }

  /// Stop accelerometer monitoring and clean up.
  void stop() {
    stopReplay();
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _inCooldown = false;
    _resetTriggerWindow();
    _resetGyroWindow();
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();
    if (!_disposed) {
      monitorState.value = EarthquakeMonitorState.idle;
      currentRatio.value = 0.0;
    }
    debugPrint('EarthquakeDetectionService: stopped');
  }

  /// Switch the detection pipeline to use an external MPU-6050 sensor stream
  /// delivered over BLE from the ESP32.
  ///
  /// Cancels the phone accelerometer and gyroscope subscriptions so the phone
  /// sensor does not compete with the external stream. The full STA/LTA +
  /// feature extraction pipeline continues to run on the incoming packets.
  ///
  /// Call [stopExternal] to revert to phone sensors.
  void startExternal(Stream<SensorPacket> stream) {
    stopReplay();
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _inCooldown = false;

    // Cancel phone sensor subscriptions — we're now using the ESP32
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    // Cancel any prior external subscription
    _externalSubscription?.cancel();
    _externalSubscription = null;

    // Reset pipeline state for a clean start
    _staLta.reset();
    // Prime LTA with a quiet baseline so detection works immediately on connect
    // instead of requiring 30 s of organic data to fill the LTA window.
    _staLta.primeWithQuietBaseline(EarthquakeConfig.externalSensorBaselineMs2);
    _stationarity.reset();
    _featureBuffer.clear();
    _resetTriggerWindow();
    _resetGyroWindow();

    _externalSubscription = stream.listen(
      (packet) {
        _onRawAccel(packet.ax, packet.ay, packet.az);
        _onRawGyro(packet.gx, packet.gy, packet.gz);
      },
      onError: (Object e) {
        debugPrint('EarthquakeDetectionService: external stream error: $e');
        stopExternal();
      },
      cancelOnError: false,
    );

    monitorState.value = EarthquakeMonitorState.monitoring;
    debugPrint('EarthquakeDetectionService: started with external ESP32 sensor stream');
  }

  /// Revert from external ESP32 sensor stream back to the phone's built-in sensors.
  ///
  /// Cancels the external subscription and restarts phone sensor monitoring.
  /// Safe to call when no external stream is active (no-op in that case).
  void stopExternal() {
    if (!_usingExternalStream) return;

    _externalSubscription?.cancel();
    _externalSubscription = null;
    debugPrint('EarthquakeDetectionService: external stream stopped, reverting to phone sensors');

    // Reset pipeline state so ESP32 baseline does not contaminate phone sensors
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();
    _resetTriggerWindow();
    _resetGyroWindow();
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;
    _inCooldown = false;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;

    // Phone sensor fallback disabled — ESP32 is the only detection source.
    monitorState.value = EarthquakeMonitorState.idle;
  }

  /// Release all resources. Call only when the service will never be used again.
  void dispose() {
    _disposed = true;
    _externalSubscription?.cancel();
    _externalSubscription = null;
    stop();
    _detectionController.close();
    _debugController.close();
    isReplaying.dispose();
    monitorState.dispose();
    lastEvent.dispose();
    currentRatio.dispose();
  }

  // ── Gyroscope processing ──────────────────────────────────────────────────

  void _onGyroSample(GyroscopeEvent event) {
    _onRawGyro(event.x, event.y, event.z);
  }

  void _onRawGyro(double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    _lastGyroMagnitude = magnitude;
    final isAbove = magnitude > EarthquakeConfig.gyroscopeVetoThreshold;

    if (isAbove) _gyroAboveCount++;
    _gyroAboveWindow.addLast(isAbove);
    if (_gyroAboveWindow.length > EarthquakeConfig.gyroscopeWindowSamples) {
      if (_gyroAboveWindow.removeFirst()) _gyroAboveCount--;
    }
  }

  // ── Sample processing ────────────────────────────────────────────────────

  void _onSample(AccelerometerEvent event) {
    _onRawAccel(event.x, event.y, event.z);
  }

  void _onRawAccel(double x, double y, double z) {
    if (_disposed) return;

    final magnitude = math.sqrt(x * x + y * y + z * z);
    final netAcc = (magnitude - 9.81).abs();

    // ── Pre-filter: Stationarity Gate ──────────────────────────────────────
    // Feed stationarity detector regardless (it needs continuous data).
    _stationarity.addSample(netAcc);

    // Layer 1: feed into STA/LTA (always, so it tracks the signal)
    final ratio = _staLta.addSample(x, y, z);
    if (ratio != currentRatio.value) currentRatio.value = ratio;

    // Maintain rolling feature buffer (4-second window)
    _featureBuffer.addLast(netAcc);
    if (_featureBuffer.length > EarthquakeConfig.featureWindowSamples) {
      _featureBuffer.removeFirst();
    }

    // During cooldown keep feeding baseline components above so the pipeline
    // has fresh, accurate state when cooldown ends — but skip trigger logic.
    if (_inCooldown) return;

    // ── Pre-filter check: phone must be stationary ─────────────────────────
    // During replay tests stationarity is always true (CSV = still phone).
    // On a real device, this blocks triggers when phone is hand-held.
    // Stationarity gate: skip for external stream (ESP32 is physically mounted —
    // always stationary by design; applying the gate would cause a 5-second
    // blind spot on every session start while the detector's buffer fills).
    if (!isReplaying.value && !_usingExternalStream && !_stationarity.isStationary) {
      // Phone is not still — don't evaluate triggers but keep feeding data.
      if (monitorState.value == EarthquakeMonitorState.suspicious) {
        monitorState.value = EarthquakeMonitorState.monitoring;
        _staLta.unfreezeLta();
      }
      // Debug: emit with blockReason even if pre-filter blocked
      if (debugForceFeatures && !_debugController.isClosed) {
        final samples = _featureBuffer.toList();
        final features = samples.length >= 10 ? FeatureExtractor.analyze(samples) : null;
        final debugInfo = EarthquakeDebugInfo(
          timestamp: DateTime.now(),
          source: EarthquakeDebugSource.live,
          staLtaRatio: ratio,
          stationarityVariance: _stationarity.currentVariance,
          peakGyroMagnitude: _lastGyroMagnitude,
          blockReason: EarthquakeBlockReason.stationarity,
          features: features,
        );
        _debugController.add(debugInfo);
        debugPrint(debugInfo.thresholdReport);
      }
      return;
    }

    // ── Pre-filter check: gyroscope veto ───────────────────────────────────
    // Earthquakes = translational only. Human handling = rotational.
    // Skip this check during replay (no gyro data in CSV).
    // NOTE: Also skipped for external stream — real deployment testing requires
    // hand-shaking the ESP32; re-enable (!_usingExternalStream &&) when field-testing
    // with actual seismic events is possible.
    if (!isReplaying.value && !_usingExternalStream &&
        _gyroAboveCount >= (EarthquakeConfig.gyroscopeWindowSamples * 0.20).ceil()) {
      if (monitorState.value == EarthquakeMonitorState.suspicious) {
        monitorState.value = EarthquakeMonitorState.monitoring;
        _staLta.unfreezeLta();
      }
      if (debugForceFeatures && !_debugController.isClosed) {
        final samples = _featureBuffer.toList();
        final features = samples.length >= 10 ? FeatureExtractor.analyze(samples) : null;
        final debugInfo = EarthquakeDebugInfo(
          timestamp: DateTime.now(),
          source: EarthquakeDebugSource.live,
          staLtaRatio: ratio,
          stationarityVariance: _stationarity.currentVariance,
          peakGyroMagnitude: _lastGyroMagnitude,
          blockReason: EarthquakeBlockReason.gyroscope,
          features: features,
        );
        _debugController.add(debugInfo);
        debugPrint(debugInfo.thresholdReport);
      }
      return;
    }

    // ── Rolling-window trigger gate ──────────────────────────────────────────
    // Push current above/below result into the fixed-size window.
    final isAbove = _staLta.isTriggered;
    if (isAbove) _triggerWindowAboveCount++;
    _triggerWindow.addLast(isAbove);

    // Evict oldest sample when window is full
    if (_triggerWindow.length > EarthquakeConfig.triggerWindowSamples) {
      if (_triggerWindow.removeFirst()) _triggerWindowAboveCount--;
    }

    // Window not yet filled — wait for enough history
    if (_triggerWindow.length < EarthquakeConfig.triggerWindowSamples) {
      return;
    }

    // Require minimum fraction of above-threshold samples in the window
    if (_triggerWindowAboveCount < EarthquakeConfig.minTriggersInWindow) {
      if (monitorState.value == EarthquakeMonitorState.suspicious) {
        monitorState.value = EarthquakeMonitorState.monitoring;
        _staLta.unfreezeLta();
      }
      _collectingPostTrigger = false;
      _postTriggerSampleCount = 0;
      return;
    }

    // Freeze LTA immediately to prevent event energy inflating the baseline.
    _staLta.freezeLta();
    monitorState.value = EarthquakeMonitorState.suspicious;

    // Post-trigger collection: wait 1 more second so the feature buffer
    // contains actual earthquake energy rather than pre-event quiet noise.
    if (!_collectingPostTrigger) {
      _collectingPostTrigger = true;
      _postTriggerSampleCount = 0;
    }

    _postTriggerSampleCount++;
    if (_postTriggerSampleCount < EarthquakeConfig.postTriggerCollectionSamples) {
      return; // still collecting — keep feeding data into _featureBuffer
    }

    // 1-second post-trigger window collected — run Layer 2 on the enriched buffer
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;

    final samples = _featureBuffer.toList();
    final features = FeatureExtractor.analyze(samples);

    // Debug emit — always, for both replay and live
    if (!_debugController.isClosed) {
      final debugInfo = EarthquakeDebugInfo(
        timestamp: DateTime.now(),
        source: isReplaying.value
            ? EarthquakeDebugSource.replay
            : EarthquakeDebugSource.live,
        staLtaRatio: ratio,
        stationarityVariance: _stationarity.currentVariance,
        peakGyroMagnitude: null, // passed gyro gate
        blockReason: features == null ? EarthquakeBlockReason.triggerGate : null,
        features: features,
      );
      _debugController.add(debugInfo);
      debugPrint(debugInfo.thresholdReport);
    }

    if (features == null || !features.isEarthquake) {
      monitorState.value = EarthquakeMonitorState.monitoring;
      _staLta.unfreezeLta();
      return;
    }

    // Both layers passed — emit event and start cooldown
    _triggerDetection(ratio, features);
  }

  void _triggerDetection(double staLtaRatio, FeatureResult features) {
    final event = EarthquakeEvent(
      timestamp: DateTime.now(),
      staLtaRatio: staLtaRatio,
      peakAcceleration: features.peakAcceleration,
      iqr: features.iqr,
      zeroCrossingRate: features.zeroCrossingRate,
      cav: features.cav,
      kurtosis: features.kurtosis,
    );

    monitorState.value = EarthquakeMonitorState.confirmed;
    lastEvent.value = event;
    if (!_detectionController.isClosed) _detectionController.add(event);

    _startCooldown();
    debugPrint('EarthquakeDetectionService: DETECTED — $event');
  }

  void _startCooldown() {
    _inCooldown = true;
    _resetTriggerWindow();
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;

    if (!_disposed) {
      monitorState.value = EarthquakeMonitorState.cooldown;
    }

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(EarthquakeConfig.cooldownDuration, () {
      _inCooldown = false;
      _staLta.unfreezeLta();
      // Clear trigger window and gyro window so the next detection
      // cycle starts from a clean slate (2s fill time acts as grace period).
      _resetTriggerWindow();
      _resetGyroWindow();
      _collectingPostTrigger = false;
      _postTriggerSampleCount = 0;
      if (monitorState.value == EarthquakeMonitorState.cooldown) {
        monitorState.value = EarthquakeMonitorState.monitoring;
      }
    });
  }

  void _resetTriggerWindow() {
    _triggerWindow.clear();
    _triggerWindowAboveCount = 0;
  }

  void _resetGyroWindow() {
    _gyroAboveWindow.clear();
    _gyroAboveCount = 0;
  }

  // ── Replay ───────────────────────────────────────────────────────────────

  /// Feeds [assetPath] (a CSV from assets/fixtures/earthquake/) through the
  /// detection pipeline at 25 Hz, as if the phone were experiencing that earthquake.
  ///
  /// The real accelerometer keeps running alongside (it won't interfere because
  /// the LTA from quiet phone movement is very low and the earthquake CSV signal
  /// dominates). Call [stopReplay] to cancel early.
  Future<void> startReplay(String assetPath) async {
    if (isReplaying.value) return;

    // Reset algorithm so the replay starts from a clean state
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();
    _resetTriggerWindow();
    _resetGyroWindow();
    _collectingPostTrigger = false;
    _postTriggerSampleCount = 0;
    _inCooldown = false;
    _cooldownTimer?.cancel();

    if (!_disposed) isReplaying.value = true;

    _replaySubscription = ReplayAccelerometerStream.fromAsset(assetPath).listen(
      _onSample,
      onError: (Object e) {
        debugPrint('EarthquakeDetectionService replay error: $e');
        if (!_disposed) isReplaying.value = false;
      },
      onDone: () {
        if (!_disposed) isReplaying.value = false;
        debugPrint('EarthquakeDetectionService: replay finished');
      },
      cancelOnError: false,
    );
  }

  /// Cancels an in-progress replay.
  void stopReplay() {
    _replaySubscription?.cancel();
    _replaySubscription = null;
    if (!_disposed) isReplaying.value = false;
  }
}
