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
    required this.pageGradient,
    required this.cardGradient,
    required this.recommendationSurface,
    required this.recommendationBorder,
    required this.recommendationInk,
    required this.recommendationInkMuted,
    required this.topicAccent,
  });

  /// Light-mode token palette per DESIGN.md.
  factory AppTokens.light() => const AppTokens(
    surface: Color(0xFFFBFAFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0F4FF),
    ink: Color(0xFF211F3D),
    inkMuted: Color(0xFF676184),
    inkSubtle: Color(0xFF9D96B8),
    border: Color(0xFFE4DFFA),
    primary: Color(0xFF6F63E8),
    primaryOn: Color(0xFFFFFFFF),
    primaryTint: Color(0xFFEEF0FF),
    secondary: Color(0xFFE46FC4),
    secondaryTint: Color(0xFFFFEAF8),
    tertiary: Color(0xFF5EADEB),
    tertiaryTint: Color(0xFFEAF7FF),
    success: Color(0xFF2F9E78),
    danger: Color(0xFFD64545),
    // Category colors stay close to the mascot palette, with gold retained
    // for the small sparkle/high-school accent.
    categoryWork: Color(0xFF5EADEB),
    categoryFamily: Color(0xFFE46FC4),
    categoryFriends: Color(0xFF6F63E8),
    categoryCollege: Color(0xFF2F9E78),
    categoryHighSchool: Color(0xFFF3B44E),
    // Saturated mascot blue/lavender/pink for high-emphasis actions.
    aiGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5E7CF2), Color(0xFF8978F4), Color(0xFFE06FC8)],
      stops: [0, .52, 1],
    ),
    pageGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFEFDFF),
        Color(0xFFEFF8FF),
        Color(0xFFF1EDFF),
        Color(0xFFFFF1FB),
      ],
      stops: [0, .34, .72, 1],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAF7FF), Color(0xFFF0EDFF), Color(0xFFFFEEFA)],
      stops: [0, .55, 1],
    ),
    // Recommendation callout: soft mascot rose surface and border.
    recommendationSurface: Color(0xFFFFF0FB),
    recommendationBorder: Color(0xFFF0C8F1),
    recommendationInk: Color(0xFF42305F),
    recommendationInkMuted: Color(0xFF766391),
    // Conversation Topics pill fill follows the mascot rose accent.
    topicAccent: Color(0xFFD970C6),
  );

  /// Dark-mode token palette per DESIGN.md. The two `*Tint` values for
  /// secondary and tertiary are not pinned in DESIGN.md and use sensible
  /// dark-mode analogs of the light tints.
  factory AppTokens.dark() => const AppTokens(
    surface: Color(0xFF151525),
    surfaceRaised: Color(0xFF23243A),
    surfaceSunken: Color(0xFF10111D),
    ink: Color(0xFFF7F5FF),
    inkMuted: Color(0xFFCCC6E8),
    inkSubtle: Color(0xFFA49CBD),
    border: Color(0xFF38344F),
    primary: Color(0xFFA8A0FF),
    primaryOn: Color(0xFFFFFFFF),
    primaryTint: Color(0xFF302C4D),
    secondary: Color(0xFFFF8FD8),
    secondaryTint: Color(0xFF3F2439),
    tertiary: Color(0xFF8DD2FF),
    tertiaryTint: Color(0xFF1F3548),
    success: Color(0xFF61D0A9),
    danger: Color(0xFFFF6B6B),
    // Slightly lighter for dark surfaces.
    categoryWork: Color(0xFF8DD2FF),
    categoryFamily: Color(0xFFFF8FD8),
    categoryFriends: Color(0xFFA8A0FF),
    categoryCollege: Color(0xFF61D0A9),
    categoryHighSchool: Color(0xFFFFC86A),
    // Dark-mode mascot gradient variants.
    aiGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7D95FF), Color(0xFFA18CFF), Color(0xFFF08BD8)],
      stops: [0, .52, 1],
    ),
    pageGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF11131F),
        Color(0xFF171A2B),
        Color(0xFF211B33),
        Color(0xFF171523),
      ],
      stops: [0, .34, .72, 1],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF243248), Color(0xFF2B2544), Color(0xFF3A2038)],
      stops: [0, .55, 1],
    ),
    // Deep rose recommendation surface for dark mode.
    recommendationSurface: Color(0xFF34243C),
    recommendationBorder: Color(0xFF715080),
    recommendationInk: Color(0xFFFFEAFE),
    recommendationInkMuted: Color(0xFFF6C7EA),
    // Mascot rose accent for dark mode.
    topicAccent: Color(0xFFF08BD8),
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
  final LinearGradient pageGradient;
  final LinearGradient cardGradient;
  final Color recommendationSurface;
  final Color recommendationBorder;
  final Color recommendationInk;
  final Color recommendationInkMuted;
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
    LinearGradient? pageGradient,
    LinearGradient? cardGradient,
    Color? recommendationSurface,
    Color? recommendationBorder,
    Color? recommendationInk,
    Color? recommendationInkMuted,
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
      pageGradient: pageGradient ?? this.pageGradient,
      cardGradient: cardGradient ?? this.cardGradient,
      recommendationSurface:
          recommendationSurface ?? this.recommendationSurface,
      recommendationBorder: recommendationBorder ?? this.recommendationBorder,
      recommendationInk: recommendationInk ?? this.recommendationInk,
      recommendationInkMuted:
          recommendationInkMuted ?? this.recommendationInkMuted,
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
      pageGradient: LinearGradient.lerp(pageGradient, other.pageGradient, t)!,
      cardGradient: LinearGradient.lerp(cardGradient, other.cardGradient, t)!,
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
      recommendationInk: Color.lerp(
        recommendationInk,
        other.recommendationInk,
        t,
      )!,
      recommendationInkMuted: Color.lerp(
        recommendationInkMuted,
        other.recommendationInkMuted,
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
