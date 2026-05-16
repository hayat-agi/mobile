import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ble/ble_service.dart';
import '../features/earthquake_detection/earthquake_detection_service.dart';
import '../features/earthquake_detection/earthquake_state.dart';
import 'earthquake_foreground_service.dart';

/// Top-level entry-point called by flutter_foreground_task when the Android
/// foreground service starts (or restarts after a task-kill).
///
/// Must be a top-level function annotated with @pragma('vm:entry-point') so
/// the Dart AOT compiler does not tree-shake it away.
@pragma('vm:entry-point')
void startTaskCallback() {
  FlutterForegroundTask.setTaskHandler(EqTaskHandler());
}

/// TaskHandler that runs inside the flutter_foreground_task isolate.
///
/// Lifecycle after task-kill:
///   1. Android restarts the ForegroundService (stopWithTask="false").
///   2. flutter_foreground_task re-spawns the Dart engine inside the service.
///   3. [startTaskCallback] is invoked → [EqTaskHandler] is registered.
///   4. [onStart] initialises BLE + earthquake detection pipeline.
///   5. [onRepeatEvent] fires on the configured interval for BLE health checks.
///   6. [onDestroy] cleans up when the service is stopped explicitly.
///
/// Constraints:
///   - No UI widgets or BuildContext available here.
///   - Platform channels work (flutter_foreground_task guarantees this).
///   - Singletons are fresh instances — they do not share state with the main
///     isolate when running in the service process after task-kill.
class EqTaskHandler extends TaskHandler {
  // SharedPreferences key used by GatewayService to persist the gateway list.
  static const String _gatewaysKey = 'persisted_gateways';

  final BleService _ble = BleService();
  final EarthquakeDetectionService _eq = EarthquakeDetectionService();
  final EarthquakeForegroundService _fg = EarthquakeForegroundService();

  StreamSubscription<EarthquakeEvent>? _detectionSub;
  bool _reconnectPending = false;

  // ── TaskHandler lifecycle ─────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[EqTaskHandler] onStart — starter: $starter');

    // Initialize local notifications so showEarthquakeAlert works in this
    // isolate (the main isolate is not running after task-kill).
    await _fg.initialize();

    // Phone-IMU detection disabled — ESP32 is the only detection source.
    // Detection starts when BLE connects and hasSensorCharacteristic is true.

    // Watch BLE connection changes and swap the detection source accordingly.
    _ble.isConnected.addListener(_onConnectionChanged);

    // Forward confirmed earthquake events to the alert notification.
    _detectionSub = _eq.detectionStream.listen(_onEarthquakeDetected);

    // Attempt an immediate BLE reconnect to the last saved gateway.
    await _tryReconnect();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (!_ble.isConnected.value) {
      debugPrint('[EqTaskHandler] heartbeat — BLE disconnected, reconnecting…');
      await _tryReconnect();
      _reconnectPending = false;
    } else if (_ble.hasSensorCharacteristic && !_eq.isUsingExternalStream) {
      // Connected but external stream not yet active — sensor char may have
      // become available after the initial isConnected listener fired.
      debugPrint('[EqTaskHandler] heartbeat — connected, attaching sensor stream');
      _eq.startExternal(_ble.sensorStream);
    } else {
      debugPrint('[EqTaskHandler] heartbeat — BLE OK');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[EqTaskHandler] onDestroy');
    _ble.isConnected.removeListener(_onConnectionChanged);
    await _detectionSub?.cancel();
    _detectionSub = null;
    _eq.stop();
  }

  // ── BLE connection listener ───────────────────────────────────────────────

  void _onConnectionChanged() {
    final connected = _ble.isConnected.value;
    if (connected && _ble.hasSensorCharacteristic) {
      _eq.startExternal(_ble.sensorStream);
      _reconnectPending = false;
      debugPrint('[EqTaskHandler] switched to external ESP32 sensor stream');
    } else if (!connected) {
      _eq.stopExternal();
      _reconnectPending = true;
      debugPrint('[EqTaskHandler] BLE disconnected — will reconnect on next heartbeat');
      // Immediate retry after short delay — don't wait for onRepeatEvent
      Future.delayed(const Duration(seconds: 2), () async {
        if (_reconnectPending) await _tryReconnect();
      });
    }
  }

  // ── Earthquake detection listener ─────────────────────────────────────────

  void _onEarthquakeDetected(EarthquakeEvent event) {
    debugPrint('[EqTaskHandler] earthquake detected — peak: '
        '${event.peakAcceleration.toStringAsFixed(2)} m/s²');

    // Fire high-priority heads-up notification.
    _fg.showEarthquakeAlert(
      peakAcceleration: event.peakAcceleration,
      timestamp: event.timestamp,
    );

    // Send a compact BLE mesh alert if connected.
    final alert =
        'EQ_ALERT:${event.timestamp.millisecondsSinceEpoch}'
        ':${event.peakAcceleration.toStringAsFixed(2)}';
    _ble.sendMessage(alert);
  }

  // ── BLE reconnect helpers ─────────────────────────────────────────────────

  /// Reads the first saved gateway id from SharedPreferences and reconnects.
  Future<void> _tryReconnect() async {
    final gatewayId = await _loadFirstGatewayId();
    if (gatewayId == null || gatewayId.isEmpty) {
      debugPrint('[EqTaskHandler] no saved gateway — skip reconnect');
      return;
    }
    debugPrint('[EqTaskHandler] reconnecting to $gatewayId (scan-free)…');
    final ok = await _ble.backgroundReconnect(gatewayId);
    debugPrint('[EqTaskHandler] reconnect result: $ok');
  }

  /// Reads the persisted gateway list (JSON array) from SharedPreferences and
  /// returns the first gateway's id, mirroring GatewayService's storage format.
  Future<String?> _loadFirstGatewayId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_gatewaysKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return null;

      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        return first['id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[EqTaskHandler] failed to load gateway id: $e');
      return null;
    }
  }
}
