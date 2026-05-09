import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Status pill / badge component.
///
/// Background tint and foreground color are derived from the semantic palette.
/// Border radius is kept at 8px (closest to the navigation token) to keep the
/// pill shape compact while still following the design system.
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
    // Light: 10% tint background / Dark: 20% tint background; border at 30%
    final bgAlpha = isDark ? 0.2 : 0.1;
    const borderAlpha = 0.3;

    switch (type) {
      case StatusType.success:
        return {
          'background': AppColors.success.withValues(alpha: bgAlpha),
          'foreground': AppColors.success,
          'border': AppColors.success.withValues(alpha: borderAlpha),
        };
      case StatusType.warning:
        // Warning uses Warning Orange for palette harmony
        return {
          'background': AppColors.warning.withValues(alpha: bgAlpha),
          'foreground': AppColors.warning,
          'border': AppColors.warning.withValues(alpha: borderAlpha),
        };
      case StatusType.danger:
        return {
          'background': AppColors.danger.withValues(alpha: bgAlpha),
          'foreground': AppColors.danger,
          'border': AppColors.danger.withValues(alpha: borderAlpha),
        };
      case StatusType.info:
        // Info uses Action Blue for palette harmony
        return {
          'background': AppColors.info.withValues(alpha: bgAlpha),
          'foreground': AppColors.info,
          'border': AppColors.info.withValues(alpha: borderAlpha),
        };
      case StatusType.neutral:
        return {
          'background': isDark ? AppColors.surfaceVariantDark : AppColors.ghostFog,
          'foreground': isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          'border': isDark
              ? AppColors.outlineDark.withValues(alpha: borderAlpha)
              : AppColors.sterlingGray.withValues(alpha: borderAlpha),
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
