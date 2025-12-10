import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoş Geldiniz'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Onboarding Ekranı',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRouter.disasterHome);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Afet Moduna Geç'),
            ),
          ],
        ),
      ),
    );
  }
}

