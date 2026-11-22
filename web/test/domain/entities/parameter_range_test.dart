import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';

void main() {
  const tempo = ParameterDefinition('tempo', 'Tempo', 0.5, 1.5, 1.0);

  group('ParameterRange.effectiveRange', () {
    test('no override -> global bounds', () {
      expect(
        ParameterRange.effectiveRange(tempo, null),
        const ParameterRange(0.5, 1.5),
      );
    });

    test('override inside global bounds is used as is', () {
      expect(
        ParameterRange.effectiveRange(tempo, const ParameterRange(0.7, 0.9)),
        const ParameterRange(0.7, 0.9),
      );
    });

    test('override can only narrow, never widen', () {
      expect(
        ParameterRange.effectiveRange(tempo, const ParameterRange(0.2, 1.2)),
        const ParameterRange(0.5, 1.2),
      );
    });

    test('disjoint or inverted override falls back to global bounds', () {
      expect(
        ParameterRange.effectiveRange(tempo, const ParameterRange(2.0, 3.0)),
        const ParameterRange(0.5, 1.5),
      );
      expect(
        ParameterRange.effectiveRange(tempo, const ParameterRange(0.9, 0.7)),
        const ParameterRange(0.5, 1.5),
      );
    });

    test('EffectPreset.rangeFor uses the preset override', () {
      const preset = EffectPreset(
        id: 'p',
        name: 'P',
        description: '',
        parameters: {},
        ranges: {'tempo': ParameterRange(0.6, 0.9)},
      );
      expect(preset.rangeFor(tempo), const ParameterRange(0.6, 0.9));
    });
  });

  group('ParameterRange JSON', () {
    test('map round-trips', () {
      const ranges = {
        'tempo': ParameterRange(0.7, 0.95),
        'pitch': ParameterRange(-6.0, 0.0),
      };
      expect(
        ParameterRange.mapFromJson(ParameterRange.mapToJson(ranges)),
        ranges,
      );
    });

    test('malformed entries are dropped', () {
      final parsed = ParameterRange.mapFromJson({
        'tempo': {'min': 0.7, 'max': 0.9},
        'pitch': {'min': 'x', 'max': 1},
        'echoAmount': {'min': 0.9, 'max': 0.1},
        'reverbAmount': 42,
      });
      expect(parsed, {'tempo': const ParameterRange(0.7, 0.9)});
      expect(ParameterRange.mapFromJson(null), isEmpty);
      expect(ParameterRange.mapFromJson('nope'), isEmpty);
    });

    test('clamp and contains', () {
      const r = ParameterRange(0.7, 0.9);
      expect(r.clamp(1.2), 0.9);
      expect(r.clamp(0.1), 0.7);
      expect(r.clamp(0.8), 0.8);
      expect(r.contains(0.9), isTrue);
      expect(r.contains(0.91), isFalse);
    });
  });
}
