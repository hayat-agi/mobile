import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'ble_service.dart';
import 'BLEConnectionManager.dart';

/// Shows a modal dialog for device activation.
/// Returns `true` if the device was activated successfully.
Future<bool> showActivationDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ActivationDialog(),
  ) ?? false;
}

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog();

  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  final _controller = TextEditingController();
  final _bleService = BleService();
  bool _loading = false;
  bool _obscure = true;
  String? _errorMessage;
  bool _activated = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Aktivasyon şifresi giriniz');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await _bleService.sendActivationPassword(password);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _loading = false;
        _activated = true;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _errorMessage = result.message;
      });

      // If locked out, disable input briefly to convey the lockout visually
      if (result.lockoutSeconds != null) {
        _controller.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _activated ? Icons.check_circle : Icons.lock_outline,
            color: _activated ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(_activated ? 'Aktive Edildi' : 'Cihaz Aktivasyonu'),
        ],
      ),
      content: _activated ? _buildSuccessContent(theme) : _buildFormContent(theme),
      actions: _activated ? null : [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Aktive Et'),
        ),
      ],
    );
  }

  Widget _buildSuccessContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: AppColors.success, size: 64),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Cihaz başarıyla aktive edildi!',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Cihaz yeniden başlatılıyor...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        const LinearProgressIndicator(),
      ],
    );
  }

  Widget _buildFormContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu cihaz henüz aktive edilmemiş. Kullanmaya başlamak için aktivasyon şifresini girin.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          obscureText: _obscure,
          enabled: !_loading,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Aktivasyon Şifresi',
            prefixIcon: const Icon(Icons.vpn_key),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: const OutlineInputBorder(),
            errorText: _errorMessage,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
