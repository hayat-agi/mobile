import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard list row component
class ListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ListTile(
      leading: leading,
      title: Text(
        title,
        style: AppTypography.titleMedium(context),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTypography.bodySmall(context).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
    );

    if (!showDivider) {
      return content;
    }

    return Column(
      children: [
        content,
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ],
    );
  }
}

