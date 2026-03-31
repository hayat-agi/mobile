import 'package:flutter/material.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/onboarding/login_page.dart';
import '../../features/onboarding/register_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/disaster_mode/disaster_home_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/profile_edit_page.dart';
import '../../features/settings/issue_report_page.dart';
import '../../features/gateway_details/gateway_details_page.dart';
import '../../features/household_profile/household_profile_page.dart';

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String disasterHome = '/disaster-home';
  static const String messages = '/messages';
  static const String settings = '/settings';
  static const String profileEdit = '/profile-edit';
  static const String issueReport = '/issue-report';
  static const String gatewayDetails = '/gateway-details';
  static const String householdProfile = '/household-profile';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case disasterHome:
        final autoTriggered = routeSettings.arguments as bool? ?? false;
        return MaterialPageRoute(
          builder: (_) => DisasterHomePage(autoTriggered: autoTriggered),
        );
      case messages:
        return MaterialPageRoute(builder: (_) => const MessagesPage());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case profileEdit:
        return MaterialPageRoute(builder: (_) => const ProfileEditPage());
      case issueReport:
        return MaterialPageRoute(builder: (_) => const IssueReportPage());
      case gatewayDetails:
        final gatewayId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => GatewayDetailsPage(gatewayId: gatewayId),
        );
      case householdProfile:
        final gatewayId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => HouseholdProfilePage(gatewayId: gatewayId),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        );
    }
  }
}

