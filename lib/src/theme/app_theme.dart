import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

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
    final primaryButtonText = AppTypography.body(
      color: tokens.primaryOn,
    ).copyWith(fontWeight: FontWeight.w700);
    final primaryButtonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    final primaryButtonPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 11,
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
          disabledBackgroundColor: tokens.primary.withValues(alpha: 0.42),
          disabledForegroundColor: tokens.primaryOn.withValues(alpha: 0.72),
          shape: primaryButtonShape,
          padding: primaryButtonPadding,
          textStyle: primaryButtonText,
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          disabledBackgroundColor: tokens.primary.withValues(alpha: 0.42),
          disabledForegroundColor: tokens.primaryOn.withValues(alpha: 0.72),
          shape: primaryButtonShape,
          padding: primaryButtonPadding,
          textStyle: primaryButtonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          disabledBackgroundColor: tokens.primary.withValues(alpha: 0.42),
          disabledForegroundColor: tokens.primaryOn.withValues(alpha: 0.72),
          side: BorderSide.none,
          shape: primaryButtonShape,
          padding: primaryButtonPadding,
          textStyle: primaryButtonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.primaryOn,
          disabledBackgroundColor: tokens.primary.withValues(alpha: 0.42),
          disabledForegroundColor: tokens.primaryOn.withValues(alpha: 0.72),
          shape: primaryButtonShape,
          padding: primaryButtonPadding,
          textStyle: primaryButtonText,
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
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
