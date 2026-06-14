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
      canvasColor: tokens.surface,
      dividerColor: tokens.border,
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
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSunken,
        hintStyle: TextStyle(color: tokens.inkSubtle),
        prefixIconColor: tokens.inkSubtle,
        suffixIconColor: tokens.inkSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: tokens.primary, width: 1.4),
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
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surfaceRaised,
        selectedColor: tokens.primary,
        disabledColor: tokens.surfaceSunken,
        labelStyle: TextStyle(color: tokens.inkMuted),
        secondaryLabelStyle: TextStyle(color: tokens.primaryOn),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tokens.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tokens.surfaceRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink,
        contentTextStyle: TextStyle(color: tokens.surfaceRaised),
        actionTextColor: tokens.primaryTint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
