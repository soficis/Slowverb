import 'dart:math' as math;

import 'effect_preset.dart';
import 'parameter_definitions.dart';

/// Every slider-backed parameter. Preset ranges ([EffectPreset.ranges]) only
/// apply to these; other keys (toggles, mastering, device) are never touched.
const List<ParameterDefinition> slideableParameterDefinitions = [
  ...effectParameterDefinitions,
  ...advancedReverbParameterDefinitions,
  phaserSpeedHzDef,
  phaserDecayDef,
  bassGainDef,
  crackleDef,
];

ParameterDefinition? slideableDefinitionFor(String id) {
  for (final def in slideableParameterDefinitions) {
    if (def.id == id) return def;
  }
  return null;
}

/// One value the editor moved to fit a preset's range, kept so the UI can say
/// what changed instead of snapping silently.
class ParameterClamp {
  final String id;
  final String label;
  final double from;
  final double to;

  const ParameterClamp({
    required this.id,
    required this.label,
    required this.from,
    required this.to,
  });

  @override
  bool operator ==(Object other) =>
      other is ParameterClamp &&
      other.id == id &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(id, from, to);

  @override
  String toString() => 'ParameterClamp($id: $from -> $to)';
}

class PresetClampResult {
  final Map<String, double> parameters;
  final List<ParameterClamp> clamps;

  const PresetClampResult(this.parameters, this.clamps);
}

/// Fits [params] into [preset]'s slider bounds.
///
/// Only parameters the preset actually ranges are considered, so unranged
/// presets leave values exactly as they were. A ranged parameter that is
/// absent from [params] is judged by its default (what the slider would show)
/// and written explicitly when the default falls outside the range.
PresetClampResult clampToPreset(
  EffectPreset preset,
  Map<String, double> params,
) {
  final out = Map<String, double>.from(params);
  final clamps = <ParameterClamp>[];
  for (final def in slideableParameterDefinitions) {
    if (!preset.ranges.containsKey(def.id)) continue;
    final range = preset.rangeFor(def);
    final current = params[def.id] ?? def.defaultValue;
    if (!current.isFinite) continue;
    final fitted = range.clamp(current);
    if (fitted != current) {
      out[def.id] = fitted;
      clamps.add(
        ParameterClamp(id: def.id, label: def.label, from: current, to: fitted),
      );
    }
  }
  return PresetClampResult(out, clamps);
}

/// Speed/pitch coupling for the single "Speed" control (W7).
///
/// Tempo and pitch are independent DSP axes: tempo time-stretches, pitch shifts
/// by semitones. "Linked" means the record-player relationship, where pitch
/// follows speed: pitch = 12 * log2(tempo).
abstract final class SpeedPitch {
  /// Semitone tolerance for treating stored values as linked.
  static const double tolerance = 0.05;

  static double pitchFor(double tempo) => 12 * math.log(tempo) / math.ln2;

  static double tempoFor(double pitch) => math.pow(2, pitch / 12).toDouble();

  static bool isLinked(Map<String, double> params) {
    final tempo = params['tempo'] ?? 1.0;
    final pitch = params['pitch'] ?? 0.0;
    if (!(tempo > 0) || !pitch.isFinite) return false;
    return (pitch - pitchFor(tempo)).abs() <= tolerance;
  }

  /// Speed slider bounds under [preset]: the tempo range, narrowed so the
  /// derived pitch also stays inside the pitch range. Never empty.
  static ParameterRange speedRange(EffectPreset preset) {
    final tempoDef = slideableDefinitionFor('tempo')!;
    final pitchDef = slideableDefinitionFor('pitch')!;
    final tempo = preset.rangeFor(tempoDef);
    final pitch = preset.rangeFor(pitchDef);
    final lo = math.max(tempo.min, tempoFor(pitch.min));
    final hi = math.min(tempo.max, tempoFor(pitch.max));
    return lo <= hi ? ParameterRange(lo, hi) : tempo;
  }

  /// Linked tempo and pitch for a requested speed, kept inside [preset]'s
  /// range. Returns the tempo actually used alongside its pitch.
  static ({double tempo, double pitch}) link(
    EffectPreset preset,
    double speed,
  ) {
    final tempo = speedRange(preset).clamp(speed);
    return (tempo: tempo, pitch: pitchFor(tempo));
  }
}
