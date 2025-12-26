/// Parameter definition for effect sliders.
///
/// Defines the metadata for each audio effect parameter including
/// id, display label, min/max range, and default value.
class ParameterDefinition {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;

  const ParameterDefinition(
    this.id,
    this.label,
    this.min,
    this.max,
    this.defaultValue,
  );
}

/// Standard parameter definitions for audio effects.
///
/// These define the available effect parameters and their ranges.
/// Used by effect sliders in the editor UI.
const List<ParameterDefinition> effectParameterDefinitions = [
  ParameterDefinition('tempo', 'Tempo', 0.5, 1.5, 1.0),
  ParameterDefinition('pitch', 'Pitch', -12.0, 12.0, 0.0),
  ParameterDefinition('reverbAmount', 'Reverb', 0.0, 1.0, 0.0),
  ParameterDefinition('echoAmount', 'Echo', 0.0, 1.0, 0.0),
  ParameterDefinition('eqWarmth', 'Warmth', 0.0, 1.0, 0.5),
];

/// Seek step in milliseconds for backward/forward navigation.
const int seekStepMs = 10000;
