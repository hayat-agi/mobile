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

  // Start earthquake detection using phone sensors (default mode).
  EarthquakeDetectionService().start();

  // Auto-switch earthquake detection source when the ESP32 connects/disconnects.
  // When connected and the ESP32 exposes the sensor characteristic, the
  // external MPU-6050 stream replaces the phone accelerometer.
  // When disconnected, the service falls back to the phone sensors automatically.
  final bleService = BleService();
  final eqService = EarthquakeDetectionService();

  bleService.isConnected.addListener(() {
    final connected = bleService.isConnected.value;
    if (connected && bleService.hasSensorCharacteristic) {
      // ESP32 just connected — switch to external MPU-6050 stream
      eqService.startExternal(bleService.sensorStream);
    } else if (connected) {
      // ESP32 connected but no sensor char — keep phone sensors running
    } else {
      // ESP32 disconnected — revert to phone sensors
      eqService.stopExternal();
    }
  });

  runApp(const MyApp());
}
