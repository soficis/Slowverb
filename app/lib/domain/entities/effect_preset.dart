import 'package:slowverb/domain/entities/effect_parameter.dart';

/// Represents a named effect preset configuration
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

  /// Convert parameters list to Map<String, double> for engine consumption
  Map<String, double> toParametersMap() {
    return {for (var param in parameters) param.id: param.defaultValue};
  }
}

/// Pre-defined effect presets for Slowverb (matching the web catalog)
abstract final class Presets {
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
        defaultValue: 0.95,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -2.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.7,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.2,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
    ],
  );

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
        defaultValue: -3.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.8,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.7,
        unit: '%',
      ),
    ],
  );

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
        defaultValue: 4.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.3,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.1,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.2,
        unit: '%',
      ),
    ],
  );

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
        defaultValue: 0.65,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -4.0,
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
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.8,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.5,
        unit: '%',
      ),
    ],
  );

  static const lofi = EffectPreset(
    id: 'lofi',
    name: 'Lo-Fi',
    description: 'Warm, relaxed lo-fi sound',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.92,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -1.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.5,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.3,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.8,
        unit: '%',
      ),
    ],
  );

  static const ambient = EffectPreset(
    id: 'ambient',
    name: 'Ambient Space',
    description: 'Ethereal, floating atmosphere',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.70,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -2.5,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.9,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.6,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.3,
        unit: '%',
      ),
    ],
  );

  static const deepBass = EffectPreset(
    id: 'deep_bass',
    name: 'Deep Bass',
    description: 'Heavy low-end focus',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.80,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -5.0,
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
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.2,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.9,
        unit: '%',
      ),
    ],
  );

  static const crystalClear = EffectPreset(
    id: 'crystal_clear',
    name: 'Crystal Clear',
    description: 'Crisp, bright sound',
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
        defaultValue: 2.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.2,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.1,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.1,
        unit: '%',
      ),
    ],
  );

  static const underwater = EffectPreset(
    id: 'underwater',
    name: 'Underwater',
    description: 'Submerged, muffled atmosphere',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.72,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -3.5,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.85,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.5,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.6,
        unit: '%',
      ),
    ],
  );

  static const synthwave = EffectPreset(
    id: 'synthwave',
    name: 'Synthwave',
    description: 'Retro 80s vibes',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 1.05,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: 1.0,
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
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.4,
        unit: '%',
      ),
    ],
  );

  static const slowMotion = EffectPreset(
    id: 'slow_motion',
    name: 'Slow Motion',
    description: 'Extreme slow-down effect',
    parameters: [
      EffectParameter(
        id: 'tempo',
        label: 'Tempo',
        min: 0.5,
        max: 1.5,
        defaultValue: 0.55,
        unit: 'x',
      ),
      EffectParameter(
        id: 'pitch',
        label: 'Pitch',
        min: -6,
        max: 6,
        defaultValue: -6.0,
        unit: 'semi',
      ),
      EffectParameter(
        id: 'reverbAmount',
        label: 'Reverb',
        min: 0,
        max: 1,
        defaultValue: 0.7,
        unit: '%',
      ),
      EffectParameter(
        id: 'wetDryMix',
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0.6,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.5,
        unit: '%',
      ),
    ],
  );

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
        label: 'Echo',
        min: 0,
        max: 1,
        defaultValue: 0,
        unit: '%',
      ),
      EffectParameter(
        id: 'eqWarmth',
        label: 'Warmth',
        min: 0,
        max: 1,
        defaultValue: 0.5,
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
    lofi,
    ambient,
    deepBass,
    crystalClear,
    underwater,
    synthwave,
    slowMotion,
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
