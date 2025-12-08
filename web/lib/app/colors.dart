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

/// Vaporwave-inspired color palette for Slowverb Web
class SlowverbColors {
  // Primary vaporwave gradient
  static const primaryPurple = Color(0xFF667EEA);
  static const primaryViolet = Color(0xFF764BA2);

  // Accent colors
  static const accentPink = Color(0xFFF093FB);
  static const accentCyan = Color(0xFF4FACFE);
  static const accentMint = Color(0xFF43E97B);

  // Background
  static const backgroundDark = Color(0xFF1A1A2E);
  static const backgroundMedium = Color(0xFF16213E);
  static const backgroundLight = Color(0xFF0F3460);

  // Surface colors
  static const surface = Color(0xFF1E1E3F);
  static const surfaceVariant = Color(0xFF2A2A4A);

  // Text
  static const textPrimary = Color(0xFFEEEEEE);
  static const textSecondary = Color(0xFFB0B0D0);
  static const textHint = Color(0xFF808099);

  // Waveform
  static const waveformActive = Color(0xFF667EEA);
  static const waveformInactive = Color(0xFF404060);
  static const playhead = Color(0xFFF093FB);

  // Success/Error
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  // Gradients
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, primaryViolet],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, accentCyan],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundMedium],
  );
}
