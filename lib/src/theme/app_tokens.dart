import 'package:flutter/material.dart';

/// Border radius scale tokens for ConnectMe.
///
/// Source of truth: `DESIGN.md` Radius section. Every widget reads radius
/// through these tokens — no raw `BorderRadius.circular()` literals.
class AppRadius {
  const AppRadius._();

  /// 8px — chips, pills, small inline pills.
  static const double sm = 8;

  /// 14px — inputs, secondary buttons.
  static const double md = 14;

  /// 18px — primary cards, sheet corners.
  static const double lg = 18;

  /// 24px — hero cards on Home only.
  static const double xl = 24;

  /// 999px — bond rings, avatar shapes (full circle).
  static const double pill = 999;
}

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
    required this.categoryFamily,
    required this.categoryFriends,
    required this.categoryCollege,
    required this.categoryHighSchool,
    required this.aiGradient,
    required this.recommendationSurface,
    required this.recommendationBorder,
    required this.topicAccent,
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
    // Category identity colors map to semantic tokens per DESIGN.md:
    // Family→tertiary/pink, Friends→primary/purple, College→success/green, HighSchool→secondary/orange.
    categoryFamily: Color(0xFFFF71CF),
    categoryFriends: Color(0xFF7C3AED),
    categoryCollege: Color(0xFF3B9D6E),
    categoryHighSchool: Color(0xFFFF8C00),
    // Pass 2 "AI surface" semantics. The aiGradient is purple-to-indigo,
    // matching primary at the start and a deeper indigo at the end.
    aiGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    ),
    // Recommendation callout: warm cream surface, golden-yellow border.
    recommendationSurface: Color(0xFFFFF8E1),
    recommendationBorder: Color(0xFFF6D372),
    // Conversation Topics pill fill: terracotta from the Figma spec.
    topicAccent: Color(0xFFE77E55),
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
    categoryFamily: Color(0xFFFF94D8),
    categoryFriends: Color(0xFF9B6BF0),
    categoryCollege: Color(0xFF5BC094),
    categoryHighSchool: Color(0xFFFFA240),
    // Pass 2 "AI surface" semantics, dark variants. Lighter purple/indigo
    // so the gradient stays readable on the deeper dark canvas.
    aiGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
    // Deep amber + muted gold for dark mode — desaturated equivalents.
    recommendationSurface: Color(0xFF3D2E0F),
    recommendationBorder: Color(0xFF8A6A2C),
    // Slightly desaturated terracotta for dark mode.
    topicAccent: Color(0xFFC85F3A),
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
  final Color categoryFamily;
  final Color categoryFriends;
  final Color categoryCollege;
  final Color categoryHighSchool;
  final LinearGradient aiGradient;
  final Color recommendationSurface;
  final Color recommendationBorder;
  final Color topicAccent;

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
    Color? categoryFamily,
    Color? categoryFriends,
    Color? categoryCollege,
    Color? categoryHighSchool,
    LinearGradient? aiGradient,
    Color? recommendationSurface,
    Color? recommendationBorder,
    Color? topicAccent,
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
      categoryFamily: categoryFamily ?? this.categoryFamily,
      categoryFriends: categoryFriends ?? this.categoryFriends,
      categoryCollege: categoryCollege ?? this.categoryCollege,
      categoryHighSchool: categoryHighSchool ?? this.categoryHighSchool,
      aiGradient: aiGradient ?? this.aiGradient,
      recommendationSurface:
          recommendationSurface ?? this.recommendationSurface,
      recommendationBorder: recommendationBorder ?? this.recommendationBorder,
      topicAccent: topicAccent ?? this.topicAccent,
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
      categoryFamily: Color.lerp(categoryFamily, other.categoryFamily, t)!,
      categoryFriends: Color.lerp(categoryFriends, other.categoryFriends, t)!,
      categoryCollege: Color.lerp(categoryCollege, other.categoryCollege, t)!,
      categoryHighSchool: Color.lerp(
        categoryHighSchool,
        other.categoryHighSchool,
        t,
      )!,
      aiGradient: LinearGradient.lerp(aiGradient, other.aiGradient, t)!,
      recommendationSurface: Color.lerp(
        recommendationSurface,
        other.recommendationSurface,
        t,
      )!,
      recommendationBorder: Color.lerp(
        recommendationBorder,
        other.recommendationBorder,
        t,
      )!,
      topicAccent: Color.lerp(topicAccent, other.topicAccent, t)!,
    );
  }

  /// Elevation level 0: no shadow (flat surface, default).
  static List<BoxShadow> elevation0() => [];

  /// Elevation level 1: cards, sheets resting on surface.
  /// Light mode: subtle shadow. Dark mode: subtle inset glow.
  static List<BoxShadow> elevation1(bool dark) => [
    BoxShadow(
      color: dark ? const Color(0x0FFFFFFF) : const Color(0x0F000000),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Elevation level 2: sheets while dragging, popovers.
  /// Light mode: deeper shadow. Dark mode: stronger glow.
  static List<BoxShadow> elevation2(bool dark) => [
    BoxShadow(
      color: dark ? const Color(0x66000000) : const Color(0x1A000000),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Ergonomic accessor: `context.tokens.primary`.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
