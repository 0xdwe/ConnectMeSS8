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
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.surface,
      // Note: `Avenir` is set but not bundled. Issue 010 replaces this with
      // Inter via google_fonts. Keep declaration so existing visual contract
      // is preserved across the wave 1 migration.
      fontFamily: 'Avenir',
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
