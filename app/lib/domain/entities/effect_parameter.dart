/// Definition of a single effect parameter
///
/// Defines the range, default value, and display properties
/// for a parameter like tempo, pitch, or reverb amount.
class EffectParameter {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  final double? step;
  final String? unit;

  const EffectParameter({
    required this.id,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step,
    this.unit,
  });
}
