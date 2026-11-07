import 'package:flutter/material.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// VaporXP Luna color palette mapped to legacy names for compatibility.
///
/// Thin alias layer over [SlowverbTokens]; new code should use
/// [SlowverbTokens] directly. Do not define raw colors here.
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
  static const backgroundMedium = SlowverbTokens.backgroundMedium;
  static const backgroundLight = SlowverbTokens.backgroundLight;

  // Surface colors
  static const surface = SlowverbTokens.surface;
  static const surfaceVariant = SlowverbTokens.surfaceVariant;

  // Text
  static const textPrimary = SlowverbTokens.textPrimary;
  static const textSecondary = SlowverbTokens.textSecondary;
  static const textHint = SlowverbTokens.textHint;

  // Waveform
  static const waveformActive = accentPink;
  static const waveformInactive = SlowverbTokens.waveformInactive;
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
