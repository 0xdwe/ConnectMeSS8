import 'package:flutter/material.dart';

/// Semantic design tokens for ConnectMe.
///
/// Source of truth: `DESIGN.md` Color section. Every widget reads colors
/// through these tokens — no raw hex outside this file and `app_theme.dart`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.border,
    required this.primary,
    required this.primaryOn,
    required this.primaryTint,
    required this.secondary,
    required this.secondaryTint,
    required this.tertiary,
    required this.tertiaryTint,
    required this.success,
    required this.danger,
    required this.categoryWork,
  });

  /// Light-mode token palette per DESIGN.md.
  factory AppTokens.light() => const AppTokens(
        surface: Color(0xFFFAF9FC),
        surfaceRaised: Color(0xFFFFFFFF),
        surfaceSunken: Color(0xFFF2F1F4),
        ink: Color(0xFF1A1A1A),
        inkMuted: Color(0xFF5C5A66),
        inkSubtle: Color(0xFF8C8995),
        border: Color(0xFFE7E4EB),
        primary: Color(0xFF7C3AED),
        primaryOn: Color(0xFFFFFFFF),
        primaryTint: Color(0xFFF1ECFA),
        secondary: Color(0xFFFF8C00),
        secondaryTint: Color(0xFFFAEEDC),
        tertiary: Color(0xFFFF71CF),
        tertiaryTint: Color(0xFFFAE0EE),
        success: Color(0xFF3B9D6E),
        danger: Color(0xFFC53030),
        // DESIGN.md → Category colors: Work uses oklch(0.580 0.080 230) ≈ #5283A8.
        // It's the one off-palette accent in the system.
        categoryWork: Color(0xFF5283A8),
      );

  /// Dark-mode token palette per DESIGN.md. The two `*Tint` values for
  /// secondary and tertiary are not pinned in DESIGN.md and use sensible
  /// dark-mode analogs of the light tints.
  factory AppTokens.dark() => const AppTokens(
        surface: Color(0xFF191820),
        surfaceRaised: Color(0xFF23222B),
        surfaceSunken: Color(0xFF15141B),
        ink: Color(0xFFF4F2F7),
        inkMuted: Color(0xFFBFBCC8),
        inkSubtle: Color(0xFF979398),
        border: Color(0xFF39373F),
        primary: Color(0xFF9B6BF0),
        primaryOn: Color(0xFFFFFFFF),
        primaryTint: Color(0xFF2A2235),
        secondary: Color(0xFFFFA240),
        secondaryTint: Color(0xFF3A2D1A),
        tertiary: Color(0xFFFF94D8),
        tertiaryTint: Color(0xFF3A2030),
        success: Color(0xFF5BC094),
        danger: Color(0xFFE25555),
        // Slightly lighter for dark surfaces.
        categoryWork: Color(0xFF7BA8C9),
      );

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color border;
  final Color primary;
  final Color primaryOn;
  final Color primaryTint;
  final Color secondary;
  final Color secondaryTint;
  final Color tertiary;
  final Color tertiaryTint;
  final Color success;
  final Color danger;
  final Color categoryWork;

  @override
  AppTokens copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? border,
    Color? primary,
    Color? primaryOn,
    Color? primaryTint,
    Color? secondary,
    Color? secondaryTint,
    Color? tertiary,
    Color? tertiaryTint,
    Color? success,
    Color? danger,
    Color? categoryWork,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryOn: primaryOn ?? this.primaryOn,
      primaryTint: primaryTint ?? this.primaryTint,
      secondary: secondary ?? this.secondary,
      secondaryTint: secondaryTint ?? this.secondaryTint,
      tertiary: tertiary ?? this.tertiary,
      tertiaryTint: tertiaryTint ?? this.tertiaryTint,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      categoryWork: categoryWork ?? this.categoryWork,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryOn: Color.lerp(primaryOn, other.primaryOn, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryTint: Color.lerp(secondaryTint, other.secondaryTint, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryTint: Color.lerp(tertiaryTint, other.tertiaryTint, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      categoryWork: Color.lerp(categoryWork, other.categoryWork, t)!,
    );
  }
}

/// Ergonomic accessor: `context.tokens.primary`.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
