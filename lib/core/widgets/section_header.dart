import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Section header component
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineSmall(context),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

