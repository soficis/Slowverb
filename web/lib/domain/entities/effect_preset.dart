/// Represents a named effect preset configuration
///
/// Each preset defines default values for tempo, pitch,
/// reverb, and other audio effect parameters.
class EffectPreset {
  final String id;
  final String name;
  final String description;
  final Map<String, double> parameters;

  const EffectPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.parameters,
  });
}

/// Pre-defined effect presets for Slowverb Web
abstract final class Presets {
  /// Classic slowed + reverb effect
  static const slowedReverb = EffectPreset(
    id: 'slowed_reverb',
    name: 'Slowed + Reverb',
    description: 'Classic dreamy vaporwave effect',
    parameters: {
      'tempo': 0.95,
      'pitch': -2.0,
      'reverbAmount': 0.7,
      'echoAmount': 0.2,
      'eqWarmth': 0.4,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Slowed + Reverb with specific settings (-25.926%)
  static const slowedReverb2 = EffectPreset(
    id: 'slowed_reverb_2',
    name: 'Slowed + Reverb 2',
    description: 'Precise -25.926% slowdown with detailed reverb',
    parameters: {
      'tempo': 0.74074, // -25.926% = multiply by 0.74074
      'pitch': -4.5, // Matching tempo slow
      'reverbAmount': 0.4, // 40% reverbance from screenshot
      'echoAmount': 0.15,
      'eqWarmth': 0.5, // Balanced warmth
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Slowed + Reverb with -19% speed and 50% reverb
  static const slowedReverb3 = EffectPreset(
    id: 'slowed_reverb_3',
    name: 'Slowed + Reverb 3',
    description: '-19% speed with balanced reverb',
    parameters: {
      'tempo': 0.81, // -19% speed from Audacity
      'pitch': -3.2, // Matching tempo slow (~19% = ~3.2 semitones)
      'reverbAmount': 0.5, // 50% reverbance
      'echoAmount': 0.2,
      'eqWarmth': 0.5, // 50% tone balance
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Warm, chill vaporwave sound
  static const vaporwaveChill = EffectPreset(
    id: 'vaporwave_chill',
    name: 'Vaporwave Chill',
    description: 'Warm, nostalgic sound with deep reverb',
    parameters: {
      'tempo': 0.78,
      'pitch': -3.0,
      'reverbAmount': 0.8,
      'echoAmount': 0.4,
      'eqWarmth': 0.7,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Sped up nightcore effect
  static const nightcore = EffectPreset(
    id: 'nightcore',
    name: 'Nightcore',
    description: 'Fast and high-pitched',
    parameters: {
      'tempo': 1.25,
      'pitch': 4.0,
      'reverbAmount': 0.3,
      'echoAmount': 0.1,
      'eqWarmth': 0.2,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Super slow with heavy echo
  static const echoSlow = EffectPreset(
    id: 'echo_slow',
    name: 'Echo Slow',
    description: 'Ultra slow with cascading echoes',
    parameters: {
      'tempo': 0.65,
      'pitch': -4.0,
      'reverbAmount': 0.6,
      'echoAmount': 0.8,
      'eqWarmth': 0.5,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Lo-fi hip hop vibes
  static const lofi = EffectPreset(
    id: 'lofi',
    name: 'Lo-Fi',
    description: 'Warm, relaxed lo-fi sound',
    parameters: {
      'tempo': 0.92,
      'pitch': -1.0,
      'reverbAmount': 0.5,
      'echoAmount': 0.3,
      'eqWarmth': 0.8,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Ambient spacey effect
  static const ambient = EffectPreset(
    id: 'ambient',
    name: 'Ambient Space',
    description: 'Ethereal, floating atmosphere',
    parameters: {
      'tempo': 0.70,
      'pitch': -2.5,
      'reverbAmount': 0.9,
      'echoAmount': 0.6,
      'eqWarmth': 0.3,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Deep bass emphasis
  static const deepBass = EffectPreset(
    id: 'deep_bass',
    name: 'Deep Bass',
    description: 'Heavy low-end focus',
    parameters: {
      'tempo': 0.80,
      'pitch': -5.0,
      'reverbAmount': 0.4,
      'echoAmount': 0.2,
      'eqWarmth': 0.9,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Crystal clear highs
  static const crystalClear = EffectPreset(
    id: 'crystal_clear',
    name: 'Crystal Clear',
    description: 'Crisp, bright sound',
    parameters: {
      'tempo': 1.0,
      'pitch': 2.0,
      'reverbAmount': 0.2,
      'echoAmount': 0.1,
      'eqWarmth': 0.1,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Dreamy underwater effect
  static const underwater = EffectPreset(
    id: 'underwater',
    name: 'Underwater',
    description: 'Submerged, muffled atmosphere',
    parameters: {
      'tempo': 0.72,
      'pitch': -3.5,
      'reverbAmount': 0.85,
      'echoAmount': 0.5,
      'eqWarmth': 0.6,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Retro 80s synthwave
  static const synthwave = EffectPreset(
    id: 'synthwave',
    name: 'Synthwave',
    description: 'Retro 80s vibes',
    parameters: {
      'tempo': 1.05,
      'pitch': 1.0,
      'reverbAmount': 0.6,
      'echoAmount': 0.4,
      'eqWarmth': 0.4,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Extreme slow motion
  static const slowMotion = EffectPreset(
    id: 'slow_motion',
    name: 'Slow Motion',
    description: 'Extreme slow-down effect',
    parameters: {
      'tempo': 0.55,
      'pitch': -6.0,
      'reverbAmount': 0.7,
      'echoAmount': 0.6,
      'eqWarmth': 0.5,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// Custom/manual preset
  static const manual = EffectPreset(
    id: 'manual',
    name: 'Manual',
    description: 'Custom adjustable parameters',
    parameters: {
      'tempo': 1.0,
      'pitch': 0.0,
      'reverbAmount': 0.0,
      'echoAmount': 0.0,
      'eqWarmth': 0.5,
      'masteringEnabled': 0.0,
      'masteringAlgorithm': 0.0,
    },
  );

  /// All available presets
  static const all = [
    slowedReverb,
    slowedReverb2,
    slowedReverb3,
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

  /// Get preset by ID, or null if not found.
  static EffectPreset? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
