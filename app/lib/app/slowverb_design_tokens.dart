import 'package:flutter/material.dart';

/// Central design tokens for the VaporXP Luna aesthetic across platforms.
abstract final class SlowverbTokens {
  // === RESPONSIVE BREAKPOINTS ===
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1200.0;

  /// Check if screen is mobile-sized (<600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpointMobile;

  /// Check if screen is tablet-sized (600-900px)
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointMobile &&
      MediaQuery.sizeOf(context).width < breakpointTablet;

  /// Check if screen is desktop-sized (>=900px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTablet;

  // === PRIMARY PALETTE (Vaporwave) ===
  static const Color primaryPink = Color(0xFFFF71CE); // HSL(320, 100%, 72%)
  static const Color primaryPurple = Color(0xFFB967FF); // HSL(274, 100%, 70%)
  static const Color primaryCyan = Color(0xFF05FFA1); // HSL(158, 100%, 50%)
  static const Color primaryBlue = Color(0xFF01CDFE); // HSL(192, 99%, 50%)

  // === SECONDARY PALETTE (Frutiger Aero Sky) ===
  static const Color aeroSkyLight = Color(0xFF87CEEB); // HSL(197, 71%, 73%)
  static const Color aeroSkyMedium = Color(0xFF5BA3C6); // HSL(200, 50%, 56%)
  static const Color aeroCloudWhite = Color(0xFFF0F8FF); // HSL(208, 100%, 97%)

  // === SURFACE COLORS ===
  static const Color surfaceBase = Color(0xFF1A1A2E);
  static const Color surfaceCard = Color(0x14FFFFFF);
  static const Color surfaceCardHover = Color(0x1FFFFFFF);
  static const Color surfaceGlass = Color(0x29FFFFFF);

  // === SEMANTIC COLORS ===
  static const Color success = Color(0xFF4ECCA3);
  static const Color warning = Color(0xFFFFD93D);
  static const Color error = Color(0xFFFF6B6B);

  // === SPACING ===
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2Xl = 48.0;

  // === RADII (XP Luna-inspired) ===
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusPill = 9999.0;

  // === SHADOWS ===
  static final BoxShadow shadowCard = BoxShadow(
    color: Colors.black.withOpacity(0.25),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static final BoxShadow shadowGlow = BoxShadow(
    color: primaryCyan.withOpacity(0.3),
    blurRadius: 30,
    spreadRadius: 5,
  );

  // === GRADIENTS ===
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2B1A3D), Color(0xFF0F1628)],
  );

  static const LinearGradient titleBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 0.5, 1.0],
    colors: [
      Color(0xFF4CC9F0),
      Color(0xFF3AA0F0),
      Color(0xFFF72585),
      Color(0xFFCC2F8D),
    ],
  );
}
