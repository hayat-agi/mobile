import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Modern card component — Ghost Fog background, 16px radius, no shadow.
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool showBorder;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.elevation,
    this.borderRadius,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppSpacing.radiusCard);

    // Resolve background: caller override > Ghost Fog in light, variant in dark
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ??
        (isDark ? AppColors.surfaceVariantDark : AppColors.ghostFog);

    return Card(
      elevation: elevation ?? 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: effectiveColor,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveRadius,
        side: showBorder ? const BorderSide(color: AppColors.sterlingGray, width: 1) : BorderSide.none,
      ),
      margin: margin ?? EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
          child: child,
        ),
      ),
    );
  }
}
