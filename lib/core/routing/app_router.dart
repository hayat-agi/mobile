import 'package:flutter/material.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/disaster_mode/disaster_home_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/gateway_details/gateway_details_page.dart';

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String disasterHome = '/disaster-home';
  static const String messages = '/messages';
  static const String settings = '/settings';
  static const String gatewayDetails = '/gateway-details';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case disasterHome:
        return MaterialPageRoute(builder: (_) => const DisasterHomePage());
      case messages:
        return MaterialPageRoute(builder: (_) => const MessagesPage());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case gatewayDetails:
        final gatewayId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => GatewayDetailsPage(gatewayId: gatewayId),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        );
    }
  }
}

