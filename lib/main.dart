import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network client
  ApiClient();

  // Initialize auth (check stored token)
  await AuthService().initialize();

  runApp(const MyApp());
}
