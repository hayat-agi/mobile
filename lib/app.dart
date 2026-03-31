import 'dart:async';
import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'features/earthquake_detection/earthquake_detection_service.dart';
import 'features/earthquake_detection/earthquake_state.dart';
import 'features/earthquake_detection/widgets/earthquake_confirm_dialog.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<EarthquakeEvent>? _earthquakeSub;

  @override
  void initState() {
    super.initState();
    _earthquakeSub =
        EarthquakeDetectionService().detectionStream.listen((event) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      // Don't show dialog if already on disaster home
      final route = ModalRoute.of(ctx);
      if (route?.settings.name == AppRouter.disasterHome) return;
      EarthquakeConfirmDialog.show(ctx, event); // ignore: use_build_context_synchronously
    });
  }

  @override
  void dispose() {
    _earthquakeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated =
        AuthService().authState.value == AuthState.authenticated;

    return MaterialApp(
      title: 'Hayat Ağı',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      navigatorKey: _navigatorKey,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: isAuthenticated ? AppRouter.dashboard : AppRouter.login,
      debugShowCheckedModeBanner: false,
    );
  }
}
