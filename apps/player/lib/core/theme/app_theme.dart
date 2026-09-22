import 'package:flutter/material.dart';

/// Application theme definitions (Material 3).
abstract final class AppTheme {
  /// Light theme.
  static ThemeData light() => _base(Brightness.light);

  /// Dark theme.
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F7B6C),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
