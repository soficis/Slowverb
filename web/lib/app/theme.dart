/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Slowverb Web theme configuration
class SlowverbTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: _buildColorScheme(),
      scaffoldBackgroundColor: SlowverbColors.backgroundDark,
      textTheme: textTheme,
      appBarTheme: _buildAppBarTheme(textTheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      sliderTheme: _buildSliderTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      cardTheme: _buildCardTheme(),
      snackBarTheme: _buildSnackBarTheme(),
    );
  }

  static ColorScheme _buildColorScheme() {
    return const ColorScheme.dark(
      primary: SlowverbColors.primaryPurple,
      onPrimary: Colors.white,
      secondary: SlowverbColors.accentPink,
      onSecondary: Colors.white,
      surface: SlowverbColors.surface,
      onSurface: SlowverbColors.textPrimary,
      error: SlowverbColors.error,
      onError: Colors.white,
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    final inter = GoogleFonts.interTextTheme(base);
    final headline = GoogleFonts.spaceGrotesk(textStyle: base.headlineMedium);
    final title = GoogleFonts.spaceGrotesk(textStyle: base.titleLarge);

    return inter.copyWith(
      headlineMedium: headline.copyWith(color: SlowverbColors.textPrimary),
      titleLarge: title.copyWith(color: SlowverbColors.textPrimary),
      bodyMedium: inter.bodyMedium?.copyWith(color: SlowverbColors.textSecondary),
      bodySmall: inter.bodySmall?.copyWith(color: SlowverbColors.textHint),
      labelLarge: inter.labelLarge?.copyWith(
        color: SlowverbColors.textPrimary,
        letterSpacing: 1.1,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(TextTheme textTheme) {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        letterSpacing: 2.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SlowverbColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 6,
        padding: const EdgeInsets.symmetric(
          horizontal: SlowverbTokens.spacingLg,
          vertical: SlowverbTokens.spacingSm + 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        ),
        shadowColor: SlowverbColors.primaryPurple.withOpacity(0.4),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SlowverbColors.accentPink,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static SliderThemeData _buildSliderTheme() {
    return SliderThemeData(
      activeTrackColor: SlowverbColors.primaryPurple,
      inactiveTrackColor: SlowverbColors.textSecondary.withOpacity(0.35),
      thumbColor: SlowverbColors.accentPink,
      overlayColor: SlowverbColors.accentPink.withOpacity(0.2),
      valueIndicatorColor: SlowverbColors.primaryPurple,
      trackHeight: 6.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
      valueIndicatorTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 12,
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme() {
    final borderRadius = BorderRadius.circular(SlowverbTokens.radiusSm);

    return InputDecorationTheme(
      filled: true,
      fillColor: SlowverbColors.surfaceVariant,
      labelStyle: const TextStyle(color: SlowverbColors.textSecondary),
      hintStyle: const TextStyle(color: SlowverbColors.textHint),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(
          color: SlowverbColors.primaryPurple,
          width: 2,
        ),
      ),
    );
  }

  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      color: SlowverbColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
      ),
      shadowColor: SlowverbTokens.shadowCard.color,
      elevation: 6,
    );
  }

  static SnackBarThemeData _buildSnackBarTheme() {
    return SnackBarThemeData(
      backgroundColor: SlowverbColors.surfaceVariant,
      contentTextStyle: GoogleFonts.inter(
        color: SlowverbColors.textPrimary,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
      ),
    );
  }
}
