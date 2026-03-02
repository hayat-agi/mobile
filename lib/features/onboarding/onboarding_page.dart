import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_tethering,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Hayat Ağı\'na Hoş Geldiniz',
                style: AppTypography.displaySmall(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Acil durumlarda yerel haberleşme sistemi',
                style: AppTypography.bodyLarge(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              PrimaryButton(
                label: 'Başla',
                icon: Icons.arrow_forward,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRouter.dashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
