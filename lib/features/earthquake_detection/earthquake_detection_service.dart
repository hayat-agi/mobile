import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'earthquake_config.dart';
import 'earthquake_state.dart';
import 'replay_accelerometer_stream.dart';
import 'algorithms/feature_extractor.dart';
import 'algorithms/sta_lta.dart';
import 'algorithms/stationarity_detector.dart';

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

  // ── Debug / diagnostics ──────────────────────────────────────────────────

  /// Current STA/LTA ratio — useful for live debug display.
  final ValueNotifier<double> currentRatio = ValueNotifier(0.0);

  /// True while a CSV replay is running.
  final ValueNotifier<bool> isReplaying = ValueNotifier(false);

  // ── Internal state ───────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _replaySubscription;
  Timer? _cooldownTimer;
  bool _inCooldown = false;

  /// Rolling window of booleans: was STA/LTA above threshold for each sample?
  /// Maintained at a fixed size of [EarthquakeConfig.triggerWindowSamples].
  final Queue<bool> _triggerWindow = Queue<bool>();

  /// Running count of `true` entries in [_triggerWindow] — avoids O(n) scan.
  int _triggerWindowAboveCount = 0;

  // ── Gyroscope tracking ───────────────────────────────────────────────────
  /// Rolling window of gyroscope magnitudes for recent-peak tracking.
  final Queue<double> _gyroWindow = Queue<double>();
  double _recentMaxGyro = 0.0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Start accelerometer monitoring. Safe to call multiple times (idempotent).
  void start() {
    if (monitorState.value != EarthquakeMonitorState.idle) return;

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
    _triggerWindow.clear();
    _triggerWindowAboveCount = 0;
    _gyroWindow.clear();
    _recentMaxGyro = 0.0;
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();
    monitorState.value = EarthquakeMonitorState.idle;
    currentRatio.value = 0.0;
    debugPrint('EarthquakeDetectionService: stopped');
  }

  /// Release all resources. Call only when the service will never be used again.
  void dispose() {
    stop();
    _detectionController.close();
    isReplaying.dispose();
  }

  // ── Gyroscope processing ──────────────────────────────────────────────────

  void _onGyroSample(GyroscopeEvent event) {
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    _gyroWindow.addLast(magnitude);
    if (_gyroWindow.length > EarthquakeConfig.gyroscopeWindowSamples) {
      _gyroWindow.removeFirst();
    }

    // Track rolling max over the window
    if (magnitude > _recentMaxGyro) {
      _recentMaxGyro = magnitude;
    } else if (_gyroWindow.length == EarthquakeConfig.gyroscopeWindowSamples) {
      // Recompute max when window is full (expired old max may have left)
      _recentMaxGyro = _gyroWindow.fold(0.0, math.max);
    }
  }

  // ── Sample processing ────────────────────────────────────────────────────

  void _onSample(AccelerometerEvent event) {
    if (_inCooldown) return;

    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final netAcc = (magnitude - 9.81).abs();

    // ── Pre-filter: Stationarity Gate ──────────────────────────────────────
    // Feed stationarity detector regardless (it needs continuous data).
    _stationarity.addSample(netAcc);

    // Layer 1: feed into STA/LTA (always, so it tracks the signal)
    final ratio = _staLta.addSample(event.x, event.y, event.z);
    currentRatio.value = ratio;

    // Maintain rolling feature buffer (4-second window)
    _featureBuffer.addLast(netAcc);
    if (_featureBuffer.length > EarthquakeConfig.featureWindowSamples) {
      _featureBuffer.removeFirst();
    }

    // ── Pre-filter check: phone must be stationary ─────────────────────────
    // During replay tests stationarity is always true (CSV = still phone).
    // On a real device, this blocks triggers when phone is hand-held.
    if (!isReplaying.value && !_stationarity.isStationary) {
      // Phone is not still — don't evaluate triggers but keep feeding data.
      if (monitorState.value == EarthquakeMonitorState.suspicious) {
        monitorState.value = EarthquakeMonitorState.monitoring;
        _staLta.unfreezeLta();
      }
      return;
    }

    // ── Pre-filter check: gyroscope veto ───────────────────────────────────
    // Earthquakes = translational only. Human handling = rotational.
    // Skip this check during replay (no gyro data in CSV).
    if (!isReplaying.value &&
        _recentMaxGyro > EarthquakeConfig.gyroscopeVetoThreshold) {
      if (monitorState.value == EarthquakeMonitorState.suspicious) {
        monitorState.value = EarthquakeMonitorState.monitoring;
        _staLta.unfreezeLta();
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
      return;
    }

    // Enough sustained activity — freeze LTA so event energy does not inflate LTA
    _staLta.freezeLta();

    // Enough sustained activity — run Layer 2 feature analysis
    monitorState.value = EarthquakeMonitorState.suspicious;
    final samples = _featureBuffer.toList();
    final features = FeatureExtractor.analyze(samples);

    if (features == null || !features.isEarthquake) {
      monitorState.value = EarthquakeMonitorState.monitoring;
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
    _detectionController.add(event);

    _startCooldown();
    debugPrint('EarthquakeDetectionService: DETECTED — $event');
  }

  void _startCooldown() {
    _inCooldown = true;
    _triggerWindow.clear();
    _triggerWindowAboveCount = 0;
    monitorState.value = EarthquakeMonitorState.cooldown;
    _staLta.reset();
    _stationarity.reset();
    _featureBuffer.clear();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(EarthquakeConfig.cooldownDuration, () {
      _inCooldown = false;
      if (monitorState.value == EarthquakeMonitorState.cooldown) {
        monitorState.value = EarthquakeMonitorState.monitoring;
      }
    });
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
    _triggerWindow.clear();
    _triggerWindowAboveCount = 0;
    _inCooldown = false;
    _cooldownTimer?.cancel();

    isReplaying.value = true;

    _replaySubscription = ReplayAccelerometerStream.fromAsset(assetPath).listen(
      _onSample,
      onError: (Object e) {
        debugPrint('EarthquakeDetectionService replay error: $e');
        isReplaying.value = false;
      },
      onDone: () {
        isReplaying.value = false;
        debugPrint('EarthquakeDetectionService: replay finished');
      },
      cancelOnError: false,
    );
  }

  /// Cancels an in-progress replay.
  void stopReplay() {
    _replaySubscription?.cancel();
    _replaySubscription = null;
    isReplaying.value = false;
  }
}
