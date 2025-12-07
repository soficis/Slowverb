import 'package:flutter/material.dart';
import 'package:slowverb/app/colors.dart';

/// Theme configuration for Slowverb
///
/// Creates a dark, vaporwave-inspired visual style with custom
/// slider, button, and card styling optimized for audio editing UI.
abstract final class SlowverbTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: SlowverbColors.deepPurple,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      textButtonTheme: _textButtonTheme,
      floatingActionButtonTheme: _fabTheme,
      sliderTheme: _sliderTheme,
      iconTheme: _iconTheme,
      textTheme: _textTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dividerTheme: _dividerTheme,
    );
  }

  static const _colorScheme = ColorScheme.dark(
    primary: SlowverbColors.hotPink,
    secondary: SlowverbColors.neonCyan,
    tertiary: SlowverbColors.lavender,
    surface: SlowverbColors.surface,
    onSurface: SlowverbColors.onSurface,
    error: SlowverbColors.error,
  );

  static const _appBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: SlowverbColors.onSurface,
    ),
    iconTheme: IconThemeData(color: SlowverbColors.onSurface),
  );

  static const _cardTheme = CardThemeData(
    color: SlowverbColors.surface,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  );

  static final _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: SlowverbColors.hotPink,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );

  static final _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: SlowverbColors.neonCyan,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
  );

  static const _fabTheme = FloatingActionButtonThemeData(
    backgroundColor: SlowverbColors.hotPink,
    foregroundColor: Colors.white,
    elevation: 8,
    shape: CircleBorder(),
  );

  static final _sliderTheme = SliderThemeData(
    activeTrackColor: SlowverbColors.neonCyan,
    inactiveTrackColor: SlowverbColors.surfaceVariant,
    thumbColor: SlowverbColors.neonCyan,
    overlayColor: SlowverbColors.neonCyan.withValues(alpha: 0.2),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
  );

  static const _iconTheme = IconThemeData(
    color: SlowverbColors.onSurface,
    size: 24,
  );

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: SlowverbColors.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: SlowverbColors.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SlowverbColors.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: SlowverbColors.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SlowverbColors.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: SlowverbColors.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: SlowverbColors.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: SlowverbColors.onSurface,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SlowverbColors.onSurfaceMuted,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: SlowverbColors.onSurfaceMuted,
    ),
  );

  static final _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: SlowverbColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SlowverbColors.neonCyan),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static const _dividerTheme = DividerThemeData(
    color: SlowverbColors.surfaceVariant,
    thickness: 1,
    space: 24,
  );
}
