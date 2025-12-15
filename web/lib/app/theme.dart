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
    final rajdhani = GoogleFonts.rajdhaniTextTheme(base);
    final headline = GoogleFonts.rajdhani(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final title = GoogleFonts.rajdhani(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    return rajdhani.copyWith(
      headlineMedium: headline.copyWith(color: SlowverbColors.textPrimary),
      titleLarge: title.copyWith(color: SlowverbColors.textPrimary),
      titleMedium: GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textPrimary,
        height: 1.3,
      ),
      titleSmall: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textPrimary,
        height: 1.3,
      ),
      bodyLarge: GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textPrimary,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: SlowverbColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: SlowverbColors.textHint,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textPrimary,
        letterSpacing: 1.2,
        height: 1.3,
      ),
      labelMedium: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textPrimary,
        letterSpacing: 1.0,
        height: 1.3,
      ),
      labelSmall: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: SlowverbColors.textSecondary,
        letterSpacing: 0.8,
        height: 1.3,
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
        shadowColor: SlowverbColors.primaryPurple.withValues(alpha: 0.4),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SlowverbColors.accentPink,
        textStyle: GoogleFonts.rajdhani(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static SliderThemeData _buildSliderTheme() {
    return SliderThemeData(
      activeTrackColor: SlowverbColors.primaryPurple,
      inactiveTrackColor: SlowverbColors.textSecondary.withValues(alpha: 0.35),
      thumbColor: SlowverbColors.accentPink,
      overlayColor: SlowverbColors.accentPink.withValues(alpha: 0.2),
      valueIndicatorColor: SlowverbColors.primaryPurple,
      trackHeight: 6.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
      valueIndicatorTextStyle: GoogleFonts.rajdhani(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
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
      contentTextStyle: GoogleFonts.rajdhani(
        color: SlowverbColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
      ),
    );
  }
}
