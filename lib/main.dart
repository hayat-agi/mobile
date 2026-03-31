import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_service.dart';
import 'features/earthquake_detection/earthquake_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network client
  ApiClient();

  // Initialize auth (check stored token)
  await AuthService().initialize();

  EarthquakeDetectionService().start();
  runApp(const MyApp());
}
