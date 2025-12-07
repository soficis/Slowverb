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

/// Vaporwave-inspired color palette for Slowverb
///
/// These colors evoke the aesthetic of slowed + reverb music:
/// deep purples, neon pinks, and dreamy cyans.
abstract final class SlowverbColors {
  // Primary Background Colors
  static const deepPurple = Color(0xFF1a0a2e);
  static const darkPurple = Color(0xFF2d1b4e);
  static const midnightBlue = Color(0xFF0f0a1a);

  // Accent Colors (Neon)
  static const hotPink = Color(0xFFff6b9d);
  static const neonCyan = Color(0xFF00ffff);
  static const electricBlue = Color(0xFF4d9de0);
  static const sunsetOrange = Color(0xFFff6b35);
  static const lavender = Color(0xFFe0aaff);
  static const softPink = Color(0xFFffb3c6);

  // Gradient Colors
  static const gradientStart = Color(0xFF2d1b4e);
  static const gradientMid = Color(0xFF1a0a2e);
  static const gradientEnd = Color(0xFF0f0a1a);

  // Functional Colors
  static const surface = Color(0xFF251639);
  static const surfaceVariant = Color(0xFF3d2a5c);
  static const onSurface = Color(0xFFe8e0f0);
  static const onSurfaceMuted = Color(0xFFa898c8);

  // Playback/Status Colors
  static const playActive = neonCyan;
  static const recording = hotPink;
  static const exporting = electricBlue;
  static const success = Color(0xFF7ae582);
  static const error = Color(0xFFff6b6b);
  static const warning = Color(0xFFffc107);

  /// Standard vaporwave gradient for backgrounds
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMid, gradientEnd],
  );

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

  /// Vaporwave sunset gradient (pink → purple → cyan)
  static const vaporwaveSunset = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFF6EC7), // Hot pink
      Color(0xFFC471ED), // Purple
      Color(0xFF7BEDFF), // Cyan
    ],
  );

  /// Grid/wireframe colors for background patterns
  static const gridColor = Color(0xFF00FFFF); // Bright cyan
  static const gridOpacity = 0.15;

  /// Scan line overlay
  static const scanLineColor = Color(0xFF6B00FF); // Purple
  static const scanLineOpacity = 0.05;
}
