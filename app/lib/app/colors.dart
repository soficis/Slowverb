import 'package:flutter/material.dart';
import 'package:slowverb/app/slowverb_design_tokens.dart';

/// VaporXP Luna palette mapped for shared use across widgets.
abstract final class SlowverbColors {
  // Primary Background Colors
  static const deepPurple = SlowverbTokens.surfaceBase;
  static const darkPurple = Color(0xFF2d1b4e);
  static const midnightBlue = Color(0xFF0f1628);

  // Accent Colors (Neon)
  static const hotPink = SlowverbTokens.primaryPink;
  static const neonCyan = SlowverbTokens.primaryCyan;
  static const electricBlue = SlowverbTokens.primaryBlue;
  static const sunsetOrange = Color(0xFFff6b35);
  static const lavender = SlowverbTokens.primaryPurple;
  static const softPink = Color(0xFFffb3c6);

  // Gradient Colors
  static const gradientStart = Color(0xFF2d1b4e);
  static const gradientMid = Color(0xFF1a0a2e);
  static const gradientEnd = Color(0xFF0f0a1a);

  // Functional Colors
  static const surface = Color(0xFF1F1B2F);
  static const surfaceVariant = Color(0xFF2A2343);
  static const onSurface = Color(0xFFF5F1FF);
  static const onSurfaceMuted = Color(0xFFCBC6DD);

  // Playback/Status Colors
  static const playActive = neonCyan;
  static const recording = hotPink;
  static const exporting = electricBlue;
  static const success = SlowverbTokens.success;
  static const error = SlowverbTokens.error;
  static const warning = SlowverbTokens.warning;

  /// Standard vaporwave gradient for backgrounds
  static const backgroundGradient = SlowverbTokens.backgroundGradient;

  /// Accent gradient for buttons and highlights
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hotPink, lavender],
  );

  /// Preset card gradients
  static const slowedReverbGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
  );

  static const vaporwaveChillGradient = LinearGradient(
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
  );

  static const nightcoreGradient = LinearGradient(
    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
  );

  static const echoSlowGradient = LinearGradient(
    colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
  );

  /// Vaporwave sunset gradient (pink + purple + cyan)
  static const vaporwaveSunset = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFF6EC7),
      Color(0xFFC471ED),
      Color(0xFF7BEDFF),
    ],
  );

  /// Grid/wireframe colors for background patterns
  static const gridColor = Color(0xFF00FFFF);
  static const gridOpacity = 0.15;

  /// Scan line overlay
  static const scanLineColor = Color(0xFF6B00FF);
  static const scanLineOpacity = 0.05;
}
