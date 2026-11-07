import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slowverb_web/app/retro/fader_shapes.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Slowverb Web theme: dark Platinum windows + hi-fi faceplate controls.
/// Body type is Rajdhani; display type (titles, readouts) uses the bundled
/// dot-matrix and segment faces via [SlowverbTokens].
class SlowverbTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);
    final squareish = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
      side: const BorderSide(color: Colors.black),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: SlowverbTokens.sunsetPink,
        onPrimary: Colors.black,
        secondary: SlowverbTokens.vfdCyan,
        onSecondary: Colors.black,
        tertiary: SlowverbTokens.sunsetViolet,
        surface: SlowverbTokens.windowBody,
        onSurface: SlowverbTokens.textPrimary,
        surfaceContainerHighest: SlowverbTokens.surfaceVariant,
        outline: Color(0xFF55546A),
        error: SlowverbTokens.error,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: SlowverbTokens.desktopTop,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: SlowverbTokens.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF24242E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: Colors.black)),
        titleTextStyle: TextStyle(
          fontFamily: SlowverbTokens.fontDot,
          fontSize: 18,
          letterSpacing: 2,
          color: SlowverbTokens.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF34343F),
          foregroundColor: SlowverbTokens.textPrimary,
          disabledBackgroundColor: const Color(0xFF26262E),
          disabledForegroundColor: SlowverbTokens.textHint,
          elevation: 2,
          shadowColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: squareish,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SlowverbTokens.sunsetPink,
          foregroundColor: Colors.black,
          shape: squareish,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SlowverbTokens.textPrimary,
          side: const BorderSide(color: Color(0xFF55546A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SlowverbTokens.sunsetPink,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: SlowverbTokens.vfdCyan,
        inactiveTrackColor: SlowverbTokens.groove,
        thumbColor: const Color(0xFFD8D7E0),
        overlayColor: SlowverbTokens.vfdCyan.withValues(alpha: 0.12),
        valueIndicatorColor: const Color(0xFF2A2A34),
        trackHeight: 4,
        thumbShape: const FaderThumbShape(),
        trackShape: const GrooveTrackShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: SlowverbTokens.fontDot,
          color: SlowverbTokens.vfdCyan,
          fontSize: 13,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF9A99A8),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SlowverbTokens.sunsetPink.withValues(alpha: 0.75)
              : SlowverbTokens.groove,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0xFF55546A)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? SlowverbTokens.vfdCyan : null,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SlowverbTokens.keyBottom,
        selectedColor: SlowverbTokens.vfdCyan.withValues(alpha: 0.16),
        side: const BorderSide(color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        ),
        labelStyle: GoogleFonts.rajdhani(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: SlowverbTokens.textPrimary,
        ),
        checkmarkColor: SlowverbTokens.vfdCyan,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SlowverbTokens.groove,
        labelStyle: const TextStyle(color: SlowverbTokens.textSecondary),
        hintStyle: const TextStyle(color: SlowverbTokens.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFF3A3A48)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
          borderSide: const BorderSide(color: Color(0xFF3A3A48)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
          borderSide: const BorderSide(color: SlowverbTokens.vfdCyan, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: SlowverbTokens.windowBody,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
          side: const BorderSide(color: Colors.black),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: SlowverbTokens.windowBody,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.black),
        ),
        titleTextStyle: TextStyle(
          fontFamily: SlowverbTokens.fontDot,
          fontSize: 17,
          letterSpacing: 1,
          color: SlowverbTokens.textPrimary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF26262F),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.black),
        ),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: SlowverbTokens.textPrimary,
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Color(0xFF26262F)),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(side: BorderSide(color: Colors.black)),
          ),
          elevation: WidgetStatePropertyAll(0),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          foregroundColor: SlowverbTokens.textPrimary,
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(220, 40),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7C8), // classic help-balloon yellow
          border: Border.all(color: Colors.black),
        ),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SlowverbTokens.vfdCyan,
        linearTrackColor: SlowverbTokens.groove,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF34343F)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF26262F),
        contentTextStyle: GoogleFonts.rajdhani(
          color: SlowverbTokens.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.black),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    TextStyle r(double size, FontWeight w, Color c, {double ls = 0}) =>
        GoogleFonts.rajdhani(
          fontSize: size,
          fontWeight: w,
          color: c,
          letterSpacing: ls,
          height: 1.3,
        );
    const dot = TextStyle(fontFamily: SlowverbTokens.fontDot, height: 1.25);

    return GoogleFonts.rajdhaniTextTheme(base).copyWith(
      displaySmall: dot.copyWith(
        fontSize: 34,
        color: SlowverbTokens.textPrimary,
      ),
      headlineMedium: dot.copyWith(
        fontSize: 26,
        letterSpacing: 2,
        color: SlowverbTokens.textPrimary,
      ),
      headlineSmall: dot.copyWith(
        fontSize: 22,
        letterSpacing: 1.5,
        color: SlowverbTokens.textPrimary,
      ),
      titleLarge: r(22, FontWeight.w700, SlowverbTokens.textPrimary),
      titleMedium: r(18, FontWeight.w700, SlowverbTokens.textPrimary),
      titleSmall: r(16, FontWeight.w700, SlowverbTokens.textPrimary),
      bodyLarge: r(17, FontWeight.w600, SlowverbTokens.textPrimary),
      bodyMedium: r(16, FontWeight.w500, SlowverbTokens.textSecondary),
      bodySmall: r(14, FontWeight.w500, SlowverbTokens.textHint),
      labelLarge: r(15, FontWeight.w700, SlowverbTokens.textPrimary, ls: 1.0),
      labelMedium: r(14, FontWeight.w600, SlowverbTokens.textPrimary, ls: 0.8),
      labelSmall: r(12, FontWeight.w600, SlowverbTokens.textSecondary, ls: 0.8),
    );
  }
}
