import 'package:flutter/material.dart';

/// Semantic color palette for the app — "AI Blueprint on Polished Glass"
/// Primary design is light; dark mode uses adapted variants.
class AppColors {
  AppColors._();

  // ── Brand / Accent ──────────────────────────────────────────────────────────
  /// Action Blue — primary CTA, links, focus rings
  static const Color primary = Color(0xFF0057F3);
  static const Color primaryLight = Color(0xFF3378FF);
  static const Color primaryDark = Color(0xFF0040C4);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Crimson Red — secondary CTA, destructive accents
  static const Color secondary = Color(0xFFDC2626);
  static const Color secondaryLight = Color(0xFFEF4444);
  static const Color secondaryDark = Color(0xFFB91C1C);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Semantic Colors ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  static const Color onSuccess = Color(0xFFFFFFFF);

  /// Amber — semantic warning (connecting state, mild alerts)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color warningDark = Color(0xFFD97706);
  static const Color onWarning = Color(0xFFFFFFFF);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFF87171);
  static const Color dangerDark = Color(0xFFDC2626);
  static const Color onDanger = Color(0xFFFFFFFF);

  /// Semantic info reuses Action Blue for palette harmony
  static const Color info = Color(0xFF0057F3);
  static const Color infoLight = Color(0xFF3378FF);
  static const Color infoDark = Color(0xFF0040C4);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ── Neutral Colors (Light Theme) ────────────────────────────────────────────
  /// Canvas White — primary page/scaffold background
  static const Color backgroundLight = Color(0xFFFFFFFF);

  /// Canvas White — card/surface background in light theme
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Ghost Fog — subtle secondary surface (cards, input fills, chips)
  static const Color surfaceVariantLight = Color(0xFFEFEFED);

  /// Sterling Gray — borders and dividers
  static const Color outlineLight = Color(0xFFD9D9D9);
  static const Color outlineVariantLight = Color(0xFFD9D9D9);

  // ── Text Colors (Light Theme) ────────────────────────────────────────────────
  /// Midnight Ink — primary body text
  static const Color textPrimaryLight = Color(0xFF090909);

  /// Mid-tone secondary label text
  static const Color textSecondaryLight = Color(0xFF5C5C5C);

  /// Tertiary / placeholder text
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  /// Disabled text
  static const Color textDisabledLight = Color(0xFFD9D9D9);

  // ── Neutral Colors (Dark Theme) ─────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color surfaceVariantDark = Color(0xFF1E1E1E);
  static const Color outlineDark = Color(0xFF2E2E2E);
  static const Color outlineVariantDark = Color(0xFF3A3A3A);

  // ── Text Colors (Dark Theme) ─────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF0F0F0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textTertiaryDark = Color(0xFF6B7280);
  static const Color textDisabledDark = Color(0xFF3A3A3A);

  // ── Status Aliases ───────────────────────────────────────────────────────────
  static const Color connected = success;
  static const Color disconnected = textSecondaryLight;
  static const Color connecting = warning;
  static const Color lowBattery = danger;

  // ── Design Token Aliases (use these in widgets for semantic clarity) ─────────
  /// Ghost Fog — use for card backgrounds, input fills, chip backgrounds
  static const Color ghostFog = Color(0xFFEFEFED);

  /// Sterling Gray — use for borders, dividers, separators
  static const Color sterlingGray = Color(0xFFD9D9D9);

  /// Midnight Ink — use for headings and primary text
  static const Color midnightInk = Color(0xFF090909);

  /// Abyssal Black — use for maximum contrast (icons, bold labels)
  static const Color abyssalBlack = Color(0xFF000000);

  // ── Helper Methods ────────────────────────────────────────────────────────────
  static Color background(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color outline(BuildContext context) {
    return Theme.of(context).colorScheme.outline;
  }
}
