import 'package:flutter/material.dart';

/// Design tokens for the "after-hours Mac + hi-fi deck" look:
/// dark Platinum-style windows on a sunset desktop, holding a late-90s
/// MP3-player faceplate with vacuum-fluorescent (VFD) readouts.
///
/// Single source of truth for colours, type families, spacing and radii.
/// Legacy names (primaryPink, surface, ...) are kept so older screens adopt
/// the look without edits; prefer the semantic names in new code.
abstract final class SlowverbTokens {
  // === TYPE FAMILIES (bundled, OFL) ===
  /// Dot-matrix display face: window titles, readout values.
  static const String fontDot = 'DotGothic16';

  /// 7-segment digits: time and big numeric readouts (digits, '-', '.', ':').
  static const String fontSeg7 = 'DSEG7';

  /// 14-segment alphanumerics: short uppercase display labels.
  static const String fontSeg14 = 'DSEG14';

  // === ACCENTS ===
  /// VFD cyan: the "lit" colour for values, active tracks, focus.
  static const Color vfdCyan = Color(0xFF6FF7E8);

  /// VFD amber: warnings, processing annunciators.
  static const Color vfdAmber = Color(0xFFFFB547);

  /// Sunset pink: the brand accent (selection, primary actions).
  static const Color sunsetPink = Color(0xFFFF71CE);

  /// Sunset violet: secondary brand accent.
  static const Color sunsetViolet = Color(0xFFB967FF);

  // Legacy accent names (mapped onto the new palette).
  static const Color primaryPink = sunsetPink;
  static const Color primaryPurple = sunsetViolet;
  static const Color primaryCyan = vfdCyan;
  static const Color primaryBlue = Color(0xFF7FB8FF);

  // === DESKTOP ===
  static const Color desktopTop = Color(0xFF120F26);
  static const Color desktopBottom = Color(0xFF2A1238);
  static const Color desktopGlow = Color(0xFFFF6EA8);

  // === WINDOWS (dark Platinum) ===
  static const Color windowBody = Color(0xFF1C1C24);
  static const Color windowBorder = Color(0xFF050507);
  static const Color windowHighlight = Color(0xFF3A3A4A);
  static const Color windowShade = Color(0xFF101016);
  static const Color titleStripeA = Color(0xFF2E2E3B);
  static const Color titleStripeB = Color(0xFF23232D);

  // === FACEPLATE + VFD ===
  static const Color faceplateTop = Color(0xFF2A2A34);
  static const Color faceplateBottom = Color(0xFF191920);
  static const Color vfdGlass = Color(0xFF041012);
  static const Color vfdDim = Color(0xFF16403C); // unlit segments / ghosting
  static const Color groove = Color(0xFF09090D);

  // === KEYS (hardware buttons) ===
  static const Color keyTop = Color(0xFF3A3A47);
  static const Color keyBottom = Color(0xFF262630);
  static const Color keyPressed = Color(0xFF1A1A22);

  // === SURFACES (legacy names) ===
  static const Color surfaceBase = desktopTop;
  static const Color surfaceCard = Color(0x14FFFFFF);
  static const Color surfaceCardHover = Color(0x1FFFFFFF);
  static const Color surfaceGlass = Color(0x29FFFFFF);
  static const Color backgroundMedium = Color(0xFF17142C);
  static const Color backgroundLight = Color(0xFF2A2640);
  static const Color surface = windowBody;
  static const Color surfaceVariant = Color(0xFF282833);

  // === TEXT ===
  static const Color textPrimary = Color(0xFFEDEBF5);

  /// 9.2:1 on [windowBody].
  static const Color textSecondary = Color(0xFFBDBACF);

  /// 5.6:1 on [windowBody] (AA for body text).
  static const Color textHint = Color(0xFF9A97AE);

  /// Engraved faceplate labels.
  static const Color label = Color(0xFFA9A6BC);

  // === WAVEFORM ===
  /// 3.3:1 against [surface] (WCAG 1.4.11 non-text contrast needs >= 3:1).
  static const Color waveformInactive = Color(0xFF6C6A94);

  // === SEMANTIC ===
  static const Color success = Color(0xFF5BE3A8);
  static const Color warning = vfdAmber;
  static const Color error = Color(0xFFFF6B6B);

  // === SPACING ===
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2Xl = 48.0;

  // === RADII (Platinum is nearly square) ===
  static const double radiusSm = 3.0;
  static const double radiusMd = 4.0;
  static const double radiusLg = 6.0;
  static const double radiusPill = 6.0;

  // === SHADOWS ===
  /// Hard offset drop shadow, as Mac windows had.
  static const BoxShadow shadowWindow = BoxShadow(
    color: Color(0xB3000000),
    offset: Offset(3, 3),
  );

  static final BoxShadow shadowCard = BoxShadow(
    color: Colors.black.withValues(alpha: 0.35),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static final BoxShadow shadowGlow = BoxShadow(
    color: vfdCyan.withValues(alpha: 0.25),
    blurRadius: 18,
    spreadRadius: 1,
  );

  /// Glow for lit VFD text.
  static List<Shadow> vfdGlow(Color c) => [
    Shadow(color: c.withValues(alpha: 0.65), blurRadius: 6),
    Shadow(color: c.withValues(alpha: 0.25), blurRadius: 14),
  ];

  // === GRADIENTS ===
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [desktopTop, desktopBottom],
  );

  static const LinearGradient faceplateGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [faceplateTop, faceplateBottom],
  );

  static const LinearGradient keyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [keyTop, keyBottom],
  );

  /// Primary key: sunset pink to violet.
  static const LinearGradient primaryKeyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF86D6), Color(0xFFB054E8)],
  );
}
