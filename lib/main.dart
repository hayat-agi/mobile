import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_service.dart';
import 'features/ble/ble_service.dart';
import 'features/earthquake_detection/earthquake_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network client
  ApiClient();

  // Initialize auth (check stored token)
  await AuthService().initialize();

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

  bleService.isConnected.addListener(() {
    final connected = bleService.isConnected.value;
    if (connected && bleService.hasSensorCharacteristic) {
      // ESP32 just connected — switch to external MPU-6050 stream
      eqService.startExternal(bleService.sensorStream);
    } else if (connected) {
      // ESP32 connected but no sensor char — do nothing (phone fallback off)
    } else {
      // ESP32 disconnected — would revert to phone sensors, but fallback is
      // disabled; stop external and leave detection idle until reconnect.
      eqService.stopExternal();
    }
  });

  runApp(const MyApp());
}
