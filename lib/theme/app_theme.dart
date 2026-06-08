import 'package:flutter/material.dart';

// Universal Theme Constants
class AppTheme {
  // Colors
  static const Color seedColor = Colors.blue;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;

  // Layout
  static const double borderRadius = 20;
  static const double padding = 16;
  static const double spacing = 16;

  // Music Player Specific
  static const double musicPlayerRadius = 20;
}

// Theme config
ThemeData buildTheme(Brightness brightness, Color seedColor) {
  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: seedColor,
  );

  return baseTheme.copyWith(
    // Global styling for all TextFields
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    // Global styling for all SnackBars
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
