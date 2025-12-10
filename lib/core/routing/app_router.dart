import 'package:flutter/material.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/disaster_mode/disaster_home_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/settings/settings_page.dart';

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String disasterHome = '/disaster-home';
  static const String messages = '/messages';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case disasterHome:
        return MaterialPageRoute(builder: (_) => const DisasterHomePage());
      case messages:
        return MaterialPageRoute(builder: (_) => const MessagesPage());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const OnboardingPage(),
        );
    }
  }
}

