import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../earthquake_config.dart';
import '../earthquake_state.dart';

/// Full-screen emergency dialog that prompts the user to confirm a detected
/// earthquake. If no response is received within [EarthquakeConfig.confirmationTimeout],
/// the app automatically transitions to Disaster Mode (the user may be trapped).
class EarthquakeConfirmDialog extends StatefulWidget {
  const EarthquakeConfirmDialog({super.key, required this.event});

  final EarthquakeEvent event;

  /// Convenience factory that opens the dialog with the correct barrier settings.
  static Future<void> show(BuildContext context, EarthquakeEvent event) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => EarthquakeConfirmDialog(event: event),
    );
  }

  @override
  State<EarthquakeConfirmDialog> createState() =>
      _EarthquakeConfirmDialogState();
}

class _EarthquakeConfirmDialogState extends State<EarthquakeConfirmDialog> {
  late int _secondsRemaining;
  late DateTime _deadline;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining =
        EarthquakeConfig.confirmationTimeout.inSeconds; // 30

    HapticFeedback.heavyImpact();

    _deadline = DateTime.now().add(EarthquakeConfig.confirmationTimeout);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _deadline.difference(DateTime.now()).inSeconds;
      setState(() => _secondsRemaining = remaining.clamp(0, EarthquakeConfig.confirmationTimeoutSeconds));
      if (_secondsRemaining <= 0) {
        _countdownTimer?.cancel();
        _navigateToDisasterHome();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _navigateToDisasterHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRouter.disasterHome,
      arguments: true,
    );
  }

  void _onConfirm() {
    _countdownTimer?.cancel();
    _navigateToDisasterHome();
  }

  void _onCancel() {
    _countdownTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AppColors.danger,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'DEPREM TESPİT EDİLDİ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deprem mi hissettiniz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                _CountdownRing(seconds: _secondsRemaining),
                const SizedBox(height: 24),
                Text(
                  'Yanıt vermezseniz otomatik olarak\nAfet Modu\'na geçilecek',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'EVET, DEPREM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'HAYIR, İPTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular countdown ring with a large seconds number in the centre.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds});

  final int seconds;

  static const int _total = EarthquakeConfig.confirmationTimeoutSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = (seconds / _total).clamp(0.0, 1.0);

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white12,
              color: _ringColor(progress),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              Text(
                'saniye kaldı',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _ringColor(double progress) {
    if (progress > 0.5) return AppColors.warning;
    if (progress > 0.25) return AppColors.dangerLight;
    return AppColors.danger;
  }
}
