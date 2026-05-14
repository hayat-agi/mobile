import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_service.dart';
import 'features/ble/ble_service.dart';
import 'features/earthquake_detection/earthquake_detection_service.dart';
import 'models/gateway.dart';
import 'models/user.dart';
import 'services/accessibility_service.dart';
import 'services/gateway_service.dart';
import 'services/earthquake_foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network client
  ApiClient();

  // Initialize auth (check stored token)
  await AuthService().initialize();

  // Load persisted accessibility preferences
  await AccessibilityService().load();

  // DEBUG ONLY: seed fake auth + gateway so household profile is testable
  // without a real backend or BLE device. Remove before release.
  if (kDebugMode && AuthService().authState.value != AuthState.authenticated) {
    AuthService().authState.value = AuthState.authenticated;
    AuthService().currentUser.value = User(
      id: 'debug-user',
      name: 'Test',
      surname: 'Kullanıcı',
      email: 'test@hayatagi.com',
    );
    await GatewayService().initialize();
    if (GatewayService().gateways.value.isEmpty) {
      GatewayService().gateways.value = [
        Gateway(
          id: 'debug-gateway-001',
          name: 'Test Cihazı',
          status: GatewayStatus.disconnected,
        ),
      ];
    }
  }

  // Initialize the foreground service wrapper (Android only; no-op elsewhere).
  // Must be called before runApp so the notification channel is created and
  // FlutterForegroundTask is configured before any BLE connect attempt.
  await EarthquakeForegroundService().initialize();

  // Phone-sensor fallback disabled: caused false positives (truck rumble, door
  // slams, washing machines) when ESP32 was not connected. Re-enable once
  // stationarity / gyro thresholds are tuned for phone-based detection.
  //
  // EarthquakeDetectionService().start();

  // Auto-switch earthquake detection source when the ESP32 connects/disconnects.
  // When connected and the ESP32 exposes the sensor characteristic, the
  // external MPU-6050 stream replaces the phone accelerometer.
  // When disconnected, reverts to phone sensors — currently disabled above.
  final bleService = BleService();
  final eqService = EarthquakeDetectionService();
  final fgService = EarthquakeForegroundService();

  // Start foreground service immediately so it is already active before the
  // app is ever backgrounded — this prevents Android from dropping the BLE
  // connection when the user switches away from the app.
  fgService.startService();

  bleService.isConnected.addListener(() {
    final connected = bleService.isConnected.value;
    if (connected && bleService.hasSensorCharacteristic) {
      eqService.startExternal(bleService.sensorStream);
      fgService.updateNotification('Hayat Ağı', 'Deprem algılama aktif');
    } else if (connected) {
      fgService.updateNotification('Hayat Ağı', 'Gateway bağlı');
    } else {
      eqService.stopExternal();
      // Phone IMU fallback disabled — false positives (phone IMU too sensitive).
      // fgService.stopService() intentionally removed: keep the service alive
      // so BLE can reconnect in the background without Android killing the process.
      fgService.updateNotification('Hayat Ağı', 'Bağlantı bekleniyor…');
    }
  });

  // Auto-send a compact BLE alert to the gateway the moment an earthquake is
  // confirmed — before the user sees or responds to any dialog. This notifies
  // the mesh network immediately regardless of user interaction.
  // Also fire a high-priority local notification so the user is alerted even
  // when the phone screen is off or the app is in the background.
  eqService.detectionStream.listen((event) {
    final alert =
        'EQ_ALERT:${event.timestamp.millisecondsSinceEpoch}:${event.peakAcceleration.toStringAsFixed(2)}';
    bleService.sendMessage(alert);

    fgService.showEarthquakeAlert(
      peakAcceleration: event.peakAcceleration,
      timestamp: event.timestamp,
    );
  });

  runApp(const MyApp());
}
