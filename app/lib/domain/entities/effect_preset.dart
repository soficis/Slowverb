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
