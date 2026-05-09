/// Spacing scale — 4px base unit
///
/// Scale: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96
class AppSpacing {
  AppSpacing._();

  // ── Base scale ────────────────────────────────────────────────────────────────
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  static const double space96 = 96.0;

  // ── Named aliases (kept for backward compatibility) ──────────────────────────
  /// 4px — tight gap, icon-to-label
  static const double xs = 4.0;

  /// 8px — inner padding, small gaps
  static const double sm = 8.0;

  /// 12px — list item vertical gap
  static const double smd = 12.0;

  /// 16px — default padding, card inner padding
  static const double md = 16.0;

  /// 24px — section spacing, comfortable breathing room
  static const double lg = 24.0;

  /// 32px — large section gaps
  static const double xl = 32.0;

  /// 48px — screen-level vertical spacing
  static const double xxl = 48.0;

  /// 64px — hero / splash spacing
  static const double xxxl = 64.0;

  // ── Semantic tokens ───────────────────────────────────────────────────────────
  /// Inner padding for cards (16px)
  static const double cardPadding = 16.0;

  /// Horizontal screen edge margin (16px)
  static const double screenPadding = 16.0;

  /// Vertical gap between sections (24px)
  static const double sectionSpacing = 24.0;

  /// Vertical gap between list items (12px)
  static const double itemSpacing = 12.0;

  /// Horizontal / vertical button padding (16px)
  static const double buttonPadding = 16.0;

  /// Input field internal padding (16px)
  static const double inputPadding = 16.0;

  // ── Border radii ──────────────────────────────────────────────────────────────
  /// Navigation items: 6px
  static const double radiusNav = 6.0;

  /// Cards: 16px
  static const double radiusCard = 16.0;

  /// Large feature containers: 24px
  static const double radiusLarge = 24.0;

  /// Buttons: 32px
  static const double radiusButton = 32.0;

  /// Special/pill buttons: 36px
  static const double radiusSpecial = 36.0;
}
