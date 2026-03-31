// lib/features/disaster_mode/widgets/pfa_support_overlay.dart
import 'package:flutter/material.dart';
import '../data/pfa_messages.dart';

class PFASupportOverlay extends StatelessWidget {
  final PfaMessage message;
  final VoidCallback onDismiss;

  const PFASupportOverlay({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A2535),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    color: Color(0xFF5BC8AF),
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Tamam',
                      style: TextStyle(color: Color(0xFF5BC8AF), fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
