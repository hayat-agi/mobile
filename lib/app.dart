import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated =
        AuthService().authState.value == AuthState.authenticated;

    return MaterialApp(
      title: 'Hayat Ağı',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: isAuthenticated ? AppRouter.dashboard : AppRouter.login,
      debugShowCheckedModeBanner: false,
    );
  }
}

