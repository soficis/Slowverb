import 'package:flutter/material.dart';

/// Screen size categories for responsive layouts.
enum ScreenSize { mobile, tablet, desktop, ultrawide }

/// Breakpoints and helpers for centering content across devices.
class ResponsiveLayout {
  static const double _mobileMax = 600;
  static const double _tabletMax = 1024;
  static const double _desktopMax = 1600;

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileMax) return ScreenSize.mobile;
    if (width < _tabletMax) return ScreenSize.tablet;
    if (width < _desktopMax) return ScreenSize.desktop;
    return ScreenSize.ultrawide;
  }

  static bool isMobile(BuildContext context) => of(context) == ScreenSize.mobile;
  static bool isTablet(BuildContext context) => of(context) == ScreenSize.tablet;
  static bool isDesktop(BuildContext context) =>
      of(context) == ScreenSize.desktop;
  static bool isUltraWide(BuildContext context) =>
      of(context) == ScreenSize.ultrawide;

  static double maxContentWidth(ScreenSize size) {
    return switch (size) {
      ScreenSize.mobile => double.infinity,
      ScreenSize.tablet => 900.0,
      ScreenSize.desktop => 1200.0,
      ScreenSize.ultrawide => 1400.0,
    };
  }

  static EdgeInsets contentPadding(ScreenSize size) {
    return switch (size) {
      ScreenSize.mobile => const EdgeInsets.all(16),
      ScreenSize.tablet => const EdgeInsets.all(24),
      ScreenSize.desktop => const EdgeInsets.all(32),
      ScreenSize.ultrawide =>
          const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
    };
  }
}
