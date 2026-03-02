import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Status pill/badge component
class StatusPill extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;
  final bool showIcon;

  const StatusPill({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors['border'] ?? Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(icon, size: 12, color: colors['foreground']),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall(context).copyWith(
              color: colors['foreground'],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case StatusType.success:
        return {
          'background': isDark
              ? AppColors.success.withOpacity(0.2)
              : AppColors.success.withOpacity(0.1),
          'foreground': AppColors.success,
          'border': AppColors.success.withOpacity(0.3),
        };
      case StatusType.warning:
        return {
          'background': isDark
              ? AppColors.warning.withOpacity(0.2)
              : AppColors.warning.withOpacity(0.1),
          'foreground': AppColors.warning,
          'border': AppColors.warning.withOpacity(0.3),
        };
      case StatusType.danger:
        return {
          'background': isDark
              ? AppColors.danger.withOpacity(0.2)
              : AppColors.danger.withOpacity(0.1),
          'foreground': AppColors.danger,
          'border': AppColors.danger.withOpacity(0.3),
        };
      case StatusType.info:
        return {
          'background': isDark
              ? AppColors.info.withOpacity(0.2)
              : AppColors.info.withOpacity(0.1),
          'foreground': AppColors.info,
          'border': AppColors.info.withOpacity(0.3),
        };
      case StatusType.neutral:
        return {
          'background': Theme.of(context).colorScheme.surfaceContainerHighest,
          'foreground': Theme.of(context).colorScheme.onSurfaceVariant,
          'border': Theme.of(context).colorScheme.outline.withOpacity(0.3),
        };
    }
  }
}

enum StatusType {
  success,
  warning,
  danger,
  info,
  neutral,
}

