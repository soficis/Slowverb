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
import 'package:slowverb/domain/entities/effect_parameter.dart';

/// Represents a named effect preset configuration
///
/// Each preset defines default values for tempo, pitch,
/// reverb, and other audio effect parameters.
class EffectPreset {
  final String id;
  final String name;
  final String description;
  final List<EffectParameter> parameters;

  const EffectPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.parameters,
  });
}

/// Pre-defined effect presets for Slowverb
abstract final class Presets {
  /// Classic slowed + reverb effect
  static const slowedReverb = EffectPreset(
    id: 'slowed_reverb',
    name: 'Slowed + Reverb',
    description: 'Classic dreamy vaporwave effect',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.85, // Balanced slowed effect (not too extreme)
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -3.0, // Moderate pitch drop
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Wet/Dry',
        min: 0,
        max: 1,
        defaultValue: 0.3,
        unit: '%',
      ),
    ],
  );

  /// Warm, chill vaporwave sound
  static const vaporwaveChill = EffectPreset(
    id: 'vaporwave_chill',
    name: 'Vaporwave Chill',
    description: 'Warm, nostalgic sound',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.78,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -3,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.35,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Wet/Dry',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
    ],
  );

  /// Fast and energetic nightcore style
  static const nightcore = EffectPreset(
    id: 'nightcore',
    name: 'Nightcore',
    description: 'Fast & energetic',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 1.25,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: 3,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.1,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Wet/Dry',
        min: 0,
        max: 1,
        defaultValue: 0.15,
        unit: '%',
      ),
    ],
  );

  /// Hazy with deep echoes
  static const echoSlow = EffectPreset(
    id: 'echo_slow',
    name: 'Echo Slow',
    description: 'Hazy with deep echoes',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.7,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -3,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.6,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Wet/Dry',
        min: 0,
        max: 1,
        defaultValue: 0.5,
        unit: '%',
      ),
    ],
  );

  /// Full manual control
  static const manual = EffectPreset(
    id: 'manual',
    name: 'Manual',
    description: 'Full control over all params',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 1.0,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: 0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Wet/Dry',
        min: 0,
        max: 1,
        defaultValue: 0,
        unit: '%',
      ),
    ],
  );

  /// All available presets
  static const all = [
    slowedReverb,
    vaporwaveChill,
    nightcore,
    echoSlow,
    manual,
  ];

  /// Get preset by ID
  static EffectPreset? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
