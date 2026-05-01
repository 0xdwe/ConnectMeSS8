import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF17201C);
  static const moss = Color(0xFF008B83);
  static const sage = Color(0xFF7EA88C);
  static const mint = Color(0xFFDDF2E5);
  static const sand = Color(0xFFFBF6EA);
  static const clay = Color(0xFFD88D67);
  static const blush = Color(0xFFF7D9CF);
  static const sky = Color(0xFFDCEBFA);

  static ThemeData data(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: moss,
      secondary: clay,
      surface: dark ? const Color(0xFF111815) : sand,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0D1311) : sand,
      fontFamily: 'Avenir',
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF18231F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B2622) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: moss,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}
