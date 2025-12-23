import 'package:flutter/material.dart';

/// Typography scale for consistent text styling
class AppTypography {
  AppTypography._();

  // Display styles (large headings)
  static TextStyle displayLarge(BuildContext context) {
    return Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ) ??
        const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        );
  }

  static TextStyle displayMedium(BuildContext context) {
    return Theme.of(context).textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.25,
        ) ??
        const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.25,
        );
  }

  static TextStyle displaySmall(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        );
  }

  // Headline styles
  static TextStyle headlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle headlineMedium(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle headlineSmall(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        );
  }

  // Title styles
  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle titleMedium(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
  }

  static TextStyle titleSmall(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
  }

  // Body styles
  static TextStyle bodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);
  }

  static TextStyle bodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
  }

  static TextStyle bodySmall(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontSize: 12);
  }

  // Label styles
  static TextStyle labelLarge(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ) ??
        const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
  }

  static TextStyle labelMedium(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium ??
        const TextStyle(fontSize: 12);
  }

  static TextStyle labelSmall(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall ??
        const TextStyle(fontSize: 10);
  }
}

