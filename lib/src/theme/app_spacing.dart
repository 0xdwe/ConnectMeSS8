/// Spacing scale tokens for ConnectMe.
///
/// Source of truth: `DESIGN.md` Spacing section. 8px base with semantic
/// naming. Every widget reads spacing through these tokens — no raw
/// `EdgeInsets` or `SizedBox` dimension literals in widget code.
///
/// Usage:
///     EdgeInsets.all(AppSpacing.space4)
///     SizedBox(height: AppSpacing.space5)
///     padding: EdgeInsets.symmetric(horizontal: AppSpacing.space6)
class AppSpacing {
  const AppSpacing._();

  /// 4px — inline icon-text gaps, tight chip spacing.
  static const double space1 = 4;

  /// 8px — tight stacking, chip gaps.
  static const double space2 = 8;

  /// 12px — list-row internal padding.
  static const double space3 = 12;

  /// 16px — default card padding (reduced from 24 per DESIGN.md).
  static const double space4 = 16;

  /// 24px — section vertical rhythm, modal padding.
  static const double space5 = 24;

  /// 32px — page-level breathing room, hero spacing.
  static const double space6 = 32;

  /// 40px — large section breaks.
  static const double space7 = 40;

  /// 48px — major section breaks.
  static const double space8 = 48;

  /// Bottom padding for tab screens to clear the 64px bottom nav bar.
  /// Not part of the spacing scale — this is a layout constant.
  static const double pageBottomPadding = 126;
}
