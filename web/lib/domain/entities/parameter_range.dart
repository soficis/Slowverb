import 'parameter_definitions.dart';

/// Closed interval [min, max] for one effect parameter.
///
/// Presets may narrow a parameter's global bounds (see [EffectPreset.ranges]).
/// A preset range can only narrow: [effectiveRange] intersects it with the
/// global definition, so a stored range can never widen a slider beyond what
/// the DSP accepts.
class ParameterRange {
  final double min;
  final double max;

  const ParameterRange(this.min, this.max);

  /// True when the bounds are finite and ordered.
  bool get isValid => min.isFinite && max.isFinite && min <= max;

  bool contains(double value) => value >= min && value <= max;

  double clamp(double value) => value.clamp(min, max).toDouble();

  Map<String, double> toJson() => {'min': min, 'max': max};

  /// Parses `{"min": x, "max": y}`; returns null for anything malformed, so a
  /// bad stored range is dropped instead of breaking the preset.
  static ParameterRange? fromJson(Object? json) {
    if (json is! Map) return null;
    final lo = json['min'];
    final hi = json['max'];
    if (lo is! num || hi is! num) return null;
    final range = ParameterRange(lo.toDouble(), hi.toDouble());
    return range.isValid ? range : null;
  }

  /// Encodes a preset's range map; empty when there are none.
  static Map<String, Map<String, double>> mapToJson(
    Map<String, ParameterRange> ranges,
  ) => {for (final e in ranges.entries) e.key: e.value.toJson()};

  /// Decodes a preset's range map, dropping malformed entries.
  static Map<String, ParameterRange> mapFromJson(Object? json) {
    if (json is! Map) return const {};
    final out = <String, ParameterRange>{};
    for (final e in json.entries) {
      final range = fromJson(e.value);
      if (e.key is String && range != null) out[e.key as String] = range;
    }
    return out;
  }

  /// Bounds a slider for [def] should use: the preset [override] intersected
  /// with the global [def] bounds. Falls back to the global bounds when there
  /// is no override or the intersection is empty.
  static ParameterRange effectiveRange(
    ParameterDefinition def,
    ParameterRange? override,
  ) {
    final global = ParameterRange(def.min, def.max);
    if (override == null || !override.isValid) return global;
    final lo = override.min > def.min ? override.min : def.min;
    final hi = override.max < def.max ? override.max : def.max;
    return lo <= hi ? ParameterRange(lo, hi) : global;
  }

  @override
  bool operator ==(Object other) =>
      other is ParameterRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ParameterRange($min, $max)';
}
