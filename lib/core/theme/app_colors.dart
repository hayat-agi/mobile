import 'package:flutter/material.dart';

/// Semantic color palette for the app
/// Supports both light and dark themes
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color onPrimary = Colors.white;

  // Secondary Colors
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF7C3AED);
  static const Color onSecondary = Colors.white;

  // Semantic Colors
  static const Color success = Color(0xFF10B981); // Green
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  static const Color onSuccess = Colors.white;

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);
  static const Color onWarning = Colors.white;

  static const Color danger = Color(0xFFEF4444); // Red
  static const Color dangerLight = Color(0xFFF87171);
  static const Color dangerDark = Color(0xFFDC2626);
  static const Color onDanger = Colors.white;

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color onInfo = Colors.white;

  // Neutral Colors (Light Theme)
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceVariantLight = Color(0xFFF3F4F6);
  static const Color outlineLight = Color(0xFFE5E7EB);
  static const Color outlineVariantLight = Color(0xFFD1D5DB);

  // Text Colors (Light Theme)
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textDisabledLight = Color(0xFFD1D5DB);

  // Neutral Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color outlineDark = Color(0xFF475569);
  static const Color outlineVariantDark = Color(0xFF64748B);

  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);

  // Status Colors
  static const Color connected = success;
  static const Color disconnected = textSecondaryLight;
  static const Color connecting = warning;
  static const Color lowBattery = danger;

  // Helper methods for theme-aware colors
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

