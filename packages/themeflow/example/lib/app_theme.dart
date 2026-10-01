import 'package:flutter/material.dart';

/// The light theme this "existing app" shipped with, written the way real
/// apps write them: explicit whites, greys and a brand color across
/// component themes. It knows nothing about dark mode.
abstract final class AppTheme {
  static const brand = Color(0xFF3D5AFE);

  static const _background = Color(0xFFF7F7F9);
  static const _line = Color(0xFFE6E6EA);
  static const _ink = Color(0xFF1B1B1F);

  static ThemeData light([Color brand = AppTheme.brand]) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: brand),
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _background,
      foregroundColor: _ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F0F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: brand, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: _line)),
    ),
    dividerTheme: const DividerThemeData(color: _line),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: _ink),
      bodySmall: TextStyle(color: Color(0xFF6B6B73)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
