import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic typography tokens for ConnectMe.
///
/// Source of truth: `DESIGN.md` Typography section. Every widget reads
/// type styles through these tokens — no raw `fontSize` or `FontWeight`
/// literals in widget code, no `fontFamily` declarations outside this
/// file and `app_theme.dart`.
///
/// Family choice: a single `GoogleFonts.inter()` for every step. DESIGN.md
/// suggests Inter Display for headings ≥24pt; Inter at weight 700 is
/// visually equivalent for the small range of sizes we use, and avoids
/// shipping a second font family. If real Inter Display becomes a
/// requirement later, swap `GoogleFonts.inter` for `GoogleFonts.interTight`
/// at the [display] and [h1] tokens — the rest of the API does not change.
///
/// Each method optionally takes an explicit `color`. When omitted, the
/// resulting `TextStyle` inherits color from `DefaultTextStyle` /
/// `TextTheme`, so callers can keep the call site short:
///
///     Text('Hi', style: AppTypography.h2(color: tokens.ink)),
///
/// Font weight is capped at 700 per DESIGN.md (no w800/w900 anywhere).
class AppTypography {
  const AppTypography._();

  /// Page hero on Home, profile screens. 32 / 1.15 / 700.
  static TextStyle display({Color? color}) => GoogleFonts.inter(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Section titles, modal titles. 26 / 1.20 / 700.
  static TextStyle h1({Color? color}) => GoogleFonts.inter(
        fontSize: 26,
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Card titles, sub-section labels. 21 / 1.25 / 600.
  static TextStyle h2({Color? color}) => GoogleFonts.inter(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Primary body, recommendation copy, list rows. 17 / 1.45 / 500.
  static TextStyle bodyLg({Color? color}) => GoogleFonts.inter(
        fontSize: 17,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Default reading size. 15 / 1.50 / 400.
  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        height: 1.50,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Metadata, dates, "5 days ago." 13 / 1.40 / 500.
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        height: 1.40,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Tabular figures for numeric alignment (bond score reveal, etc.).
  /// 15 / 1.40 / 500 with `FontFeature.tabularFigures()`.
  static TextStyle monoTabular({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        height: 1.40,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Escape hatch for non-typographic glyphs that don't fit the 7-step
  /// scale: emoji rendered as icons (avatars, brand marks) and
  /// dynamically-sized numeric displays (e.g. a ring score that scales
  /// with the ring size). Prefer the named tokens above for normal
  /// body copy and headings; this exists so widget code never has to
  /// hard-code `fontSize:` literals.
  static TextStyle glyph(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  /// Material `TextTheme` derived from Inter, for consumers that read
  /// `Theme.of(context).textTheme` (e.g. `AppBar`, `Dialog`, defaults).
  /// Returns a `TextTheme` where every slot is Inter; sizes/weights stay
  /// at Material defaults so legacy code that relied on them is preserved.
  static TextTheme buildTextTheme(TextTheme base) =>
      GoogleFonts.interTextTheme(base);
}
