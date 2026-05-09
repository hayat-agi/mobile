import 'package:flutter/material.dart';

/// Typography scale — "AI Blueprint on Polished Glass"
///
/// Font family: Inter (system fallback on most platforms; add via google_fonts
/// or asset bundle for guaranteed rendering).
///
/// Design scale:
///   caption    14sp  lh 1.49  ls -0.056px
///   body       16sp  lh 1.40  ls -0.064px
///   subheading 32sp  lh 1.10  ls -0.32px
///   heading-sm 40sp  lh 1.10  ls -0.44px
///   heading    48sp  lh 1.10  ls -0.96px
///   display    83sp  lh 0.95  ls -2.49px
class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Inter';

  // ── Design-scale static styles (use these for pixel-precise fidelity) ───────

  /// 83sp / lh 0.95 / ls -2.49px — hero numbers, splash screens
  static const TextStyle display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 83,
    height: 0.95,
    letterSpacing: -2.49,
    fontWeight: FontWeight.w700,
  );

  /// 48sp / lh 1.10 / ls -0.96px — page-level headings
  static const TextStyle heading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    height: 1.1,
    letterSpacing: -0.96,
    fontWeight: FontWeight.w700,
  );

  /// 40sp / lh 1.10 / ls -0.44px — section headings
  static const TextStyle headingSm = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    height: 1.1,
    letterSpacing: -0.44,
    fontWeight: FontWeight.w600,
  );

  /// 32sp / lh 1.10 / ls -0.32px — card titles, subheadings
  static const TextStyle subheading = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    height: 1.1,
    letterSpacing: -0.32,
    fontWeight: FontWeight.w600,
  );

  /// 16sp / lh 1.40 / ls -0.064px — default body text
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.4,
    letterSpacing: -0.064,
    fontWeight: FontWeight.w400,
  );

  /// 14sp / lh 1.49 / ls -0.056px — captions, secondary labels
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.49,
    letterSpacing: -0.056,
    fontWeight: FontWeight.w400,
  );

  // ── Context-aware helpers (delegate to ThemeData then fall back) ─────────────
  // These preserve the existing public API consumed by widgets throughout the app.

  static TextStyle displayLarge(BuildContext context) {
    return Theme.of(context).textTheme.displayLarge?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 83,
              height: 0.95,
              letterSpacing: -2.49,
            ) ??
        display;
  }

  static TextStyle displayMedium(BuildContext context) {
    return Theme.of(context).textTheme.displayMedium?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 48,
              height: 1.1,
              letterSpacing: -0.96,
            ) ??
        heading;
  }

  static TextStyle displaySmall(BuildContext context) {
    return Theme.of(context).textTheme.displaySmall?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 40,
              height: 1.1,
              letterSpacing: -0.44,
            ) ??
        headingSm;
  }

  // ── Headline ─────────────────────────────────────────────────────────────────

  static TextStyle headlineLarge(BuildContext context) {
    return Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 32,
              height: 1.1,
              letterSpacing: -0.32,
            ) ??
        subheading;
  }

  static TextStyle headlineMedium(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 24,
              height: 1.15,
              letterSpacing: -0.24,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 24,
          height: 1.15,
          letterSpacing: -0.24,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle headlineSmall(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              height: 1.2,
              letterSpacing: -0.2,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          height: 1.2,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w600,
        );
  }

  // ── Title ────────────────────────────────────────────────────────────────────

  static TextStyle titleLarge(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 18,
              height: 1.3,
              letterSpacing: -0.072,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          height: 1.3,
          letterSpacing: -0.072,
          fontWeight: FontWeight.w600,
        );
  }

  static TextStyle titleMedium(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 16,
              height: 1.4,
              letterSpacing: -0.064,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          height: 1.4,
          letterSpacing: -0.064,
          fontWeight: FontWeight.w500,
        );
  }

  static TextStyle titleSmall(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.49,
              letterSpacing: -0.056,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          height: 1.49,
          letterSpacing: -0.056,
          fontWeight: FontWeight.w500,
        );
  }

  // ── Body ─────────────────────────────────────────────────────────────────────

  static TextStyle bodyLarge(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: _fontFamily,
              fontSize: 16,
              height: 1.4,
              letterSpacing: -0.064,
            ) ??
        body;
  }

  static TextStyle bodyMedium(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: _fontFamily,
              fontSize: 14,
              height: 1.49,
              letterSpacing: -0.056,
            ) ??
        caption;
  }

  static TextStyle bodySmall(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize: 12,
              height: 1.5,
              letterSpacing: -0.04,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          height: 1.5,
          letterSpacing: -0.04,
        );
  }

  // ── Label ────────────────────────────────────────────────────────────────────

  static TextStyle labelLarge(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.49,
              letterSpacing: -0.056,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          height: 1.49,
          letterSpacing: -0.056,
          fontWeight: FontWeight.w500,
        );
  }

  static TextStyle labelMedium(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: _fontFamily,
              fontSize: 12,
              height: 1.5,
              letterSpacing: -0.04,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          height: 1.5,
          letterSpacing: -0.04,
        );
  }

  static TextStyle labelSmall(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: _fontFamily,
              fontSize: 10,
              height: 1.5,
              letterSpacing: 0.0,
            ) ??
        const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 10,
          height: 1.5,
          letterSpacing: 0.0,
        );
  }
}
