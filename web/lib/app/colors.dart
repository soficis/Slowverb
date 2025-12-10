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
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// VaporXP Luna color palette mapped to legacy names for compatibility.
class SlowverbColors {
  // Primary palette
  static const primaryPurple = SlowverbTokens.primaryPurple;
  static const primaryViolet = SlowverbTokens.primaryPink;

  // Accent colors
  static const accentPink = SlowverbTokens.primaryPink;
  static const accentCyan = SlowverbTokens.primaryBlue;
  static const accentMint = SlowverbTokens.primaryCyan;

  // Aliases for cross-platform compatibility
  static const neonCyan = SlowverbTokens.primaryCyan;
  static const hotPink = SlowverbTokens.primaryPink;

  // Background
  static const backgroundDark = SlowverbTokens.surfaceBase;
  static const backgroundMedium = Color(0xFF0F1628);
  static const backgroundLight = Color(0xFF23304A);

  // Surface colors
  static const surface = Color(0xFF1F1B2F);
  static const surfaceVariant = Color(0xFF2A2343);

  // Text
  static const textPrimary = Color(0xFFF5F1FF);
  static const textSecondary = Color(0xFFCBC6DD);
  static const textHint = Color(0xFF9FA4BF);

  // Waveform
  static const waveformActive = accentPink;
  static const waveformInactive = Color(0xFF3B3A55);
  static const playhead = accentCyan;

  // Success/Error
  static const success = SlowverbTokens.success;
  static const error = SlowverbTokens.error;
  static const warning = SlowverbTokens.warning;

  // Gradients
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, accentPink],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPink, accentCyan],
  );

  // Cross-platform gradient aliases
  static const vaporwaveSunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hotPink, accentCyan],
  );

  static const backgroundGradient = SlowverbTokens.backgroundGradient;
}
