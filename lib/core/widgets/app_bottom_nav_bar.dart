import 'package:flutter/material.dart';

import '../routing/app_router.dart';
import '../theme/app_colors.dart';

enum AppNavItem { home, householdProfile, settings }

class AppBottomNavBar extends StatelessWidget {
  final AppNavItem currentItem;
  final String? householdGatewayId;

  const AppBottomNavBar({
    super.key,
    required this.currentItem,
    this.householdGatewayId,
  });

  String _routeFor(AppNavItem item) {
    switch (item) {
      case AppNavItem.home:
        return AppRouter.dashboard;
      case AppNavItem.householdProfile:
        return AppRouter.householdProfile;
      case AppNavItem.settings:
        return AppRouter.settings;
    }
  }

  void _navigate(BuildContext context, int index) {
    final item = AppNavItem.values[index];
    final targetRoute = _routeFor(item);
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (item == currentItem && targetRoute == currentRoute) return;

    switch (item) {
      case AppNavItem.home:
      case AppNavItem.settings:
        Navigator.pushReplacementNamed(context, targetRoute);
        return;
      case AppNavItem.householdProfile:
        Navigator.pushReplacementNamed(
          context,
          targetRoute,
          arguments: householdGatewayId,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NavigationBar(
      selectedIndex: currentItem.index,
      onDestinationSelected: (index) => _navigate(context, index),
      height: 72,
      elevation: 0,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: AppColors.primary),
          label: 'Ana Sayfa',
        ),
        NavigationDestination(
          icon: const Icon(Icons.family_restroom_outlined),
          selectedIcon: Icon(Icons.family_restroom, color: AppColors.primary),
          label: 'Hane Profili',
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: AppColors.primary),
          label: 'Ayarlar',
        ),
      ],
    );
  }
}
