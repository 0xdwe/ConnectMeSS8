import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData data(bool dark) {
    final tokens = dark ? AppTokens.dark() : AppTokens.light();
    final scheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: tokens.primary,
      onPrimary: tokens.primaryOn,
      secondary: tokens.secondary,
      surface: tokens.surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    return base.copyWith(
      scaffoldBackgroundColor: tokens.surface,
      // Typography note: Inter is applied at the widget call site via
      // AppTypography.X(...). We deliberately do NOT call
      // GoogleFonts.interTextTheme here because it triggers async font
      // asset loading during theme construction, which breaks unit tests
      // that build a theme outside a widget binding (no
      // TestWidgetsFlutterBinding.ensureInitialized). Material defaults
      // (AppBar titles, Dialog text, etc.) keep the system family; every
      // widget we own already routes through AppTypography.
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: TextStyle(
          color: tokens.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
