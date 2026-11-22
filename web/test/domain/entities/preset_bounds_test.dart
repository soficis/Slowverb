import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';
import 'package:slowverb_web/domain/entities/preset_bounds.dart';

const _ranged = EffectPreset(
  id: 'test_ranged',
  name: 'Ranged',
  description: '',
  parameters: {'tempo': 0.9},
  ranges: {
    'tempo': ParameterRange(0.8, 1.0),
    'pitch': ParameterRange(-4.0, 0.0),
    'eqWarmth': ParameterRange(0.6, 1.0), // default 0.5 sits outside
  },
);

void main() {
  group('clampToPreset', () {
    test('unranged preset leaves every value untouched', () {
      final params = {'tempo': 1.49, 'pitch': 11.0, 'bassGain': 19.0};
      final r = clampToPreset(Presets.slowedReverb, params);
      expect(r.parameters, params);
      expect(r.clamps, isEmpty);
    });

    test('out-of-range values are moved and every move is reported', () {
      final r = clampToPreset(_ranged, {
        'tempo': 1.2,
        'pitch': -6.0,
        'eqWarmth': 0.8,
        'bassGain': 15.0, // unranged here: kept
      });
      expect(r.parameters['tempo'], 1.0);
      expect(r.parameters['pitch'], -4.0);
      expect(r.parameters['eqWarmth'], 0.8);
      expect(r.parameters['bassGain'], 15.0);
      expect(r.clamps, [
        const ParameterClamp(id: 'tempo', label: 'Tempo', from: 1.2, to: 1.0),
        const ParameterClamp(id: 'pitch', label: 'Pitch', from: -6.0, to: -4.0),
      ]);
    });

    test('absent ranged key is judged by its default and written', () {
      final r = clampToPreset(_ranged, {'tempo': 0.9, 'pitch': -1.0});
      expect(r.parameters['eqWarmth'], 0.6);
      expect(r.clamps.single.id, 'eqWarmth');
      expect(r.clamps.single.from, 0.5);
    });

    test('non-slider keys are never touched', () {
      final r = clampToPreset(_ranged, {
        'tempo': 0.9,
        'pitch': -1.0,
        'eqWarmth': 0.7,
        'masteringTargetLufs': -40.0,
        'hqReverb': 1.0,
      });
      expect(r.parameters['masteringTargetLufs'], -40.0);
      expect(r.parameters['hqReverb'], 1.0);
      expect(r.clamps, isEmpty);
    });

    test('built-in presets sit inside their own ranges', () {
      for (final preset in Presets.all) {
        final r = clampToPreset(preset, preset.parameters);
        expect(r.clamps, isEmpty, reason: preset.id);
      }
    });
  });

  group('authored ranges (W6.T3)', () {
    test('only the club and lo-fi presets are ranged', () {
      final ranged = [
        for (final p in Presets.all)
          if (p.ranges.isNotEmpty) p.id,
      ];
      expect(ranged, unorderedEquals(['retro_nightcore', 'lofi']));
    });

    test('ranges only narrow and stay valid', () {
      for (final preset in Presets.all) {
        for (final e in preset.ranges.entries) {
          final def = slideableDefinitionFor(e.key);
          expect(def, isNotNull, reason: '${preset.id}.${e.key}');
          expect(e.value.isValid, isTrue);
          expect(
            preset.rangeFor(def!),
            e.value,
            reason: 'range must lie inside the global bounds',
          );
        }
      }
    });

    test('linked speed range is not empty for ranged presets', () {
      for (final preset in [Presets.retroNightcore, Presets.lofi]) {
        final r = SpeedPitch.speedRange(preset);
        expect(r.max - r.min, greaterThan(0.1), reason: preset.id);
      }
    });
  });

  group('SpeedPitch', () {
    test('pitchFor follows 12*log2(tempo)', () {
      expect(SpeedPitch.pitchFor(1.0), 0.0);
      expect(SpeedPitch.pitchFor(2.0), closeTo(12.0, 1e-9));
      expect(SpeedPitch.pitchFor(0.86), closeTo(-2.611, 1e-3));
      expect(
        SpeedPitch.tempoFor(SpeedPitch.pitchFor(0.77)),
        closeTo(0.77, 1e-12),
      );
    });

    test('isLinked uses a 0.05 st tolerance', () {
      expect(SpeedPitch.isLinked(Presets.liteSlowedReverb.parameters), isTrue);
      expect(SpeedPitch.isLinked(Presets.manual.parameters), isTrue);
      expect(SpeedPitch.isLinked(const {}), isTrue); // 1.0x, 0 st
      // Presets that set pitch independently open separated (no silent
      // discard of their pitch).
      expect(SpeedPitch.isLinked(Presets.slowedReverb.parameters), isFalse);
      expect(SpeedPitch.isLinked(Presets.lofi.parameters), isFalse);
      expect(
        SpeedPitch.isLinked({
          'tempo': 0.9,
          'pitch': SpeedPitch.pitchFor(0.9) + 0.04,
        }),
        isTrue,
      );
      expect(
        SpeedPitch.isLinked({
          'tempo': 0.9,
          'pitch': SpeedPitch.pitchFor(0.9) + 0.06,
        }),
        isFalse,
      );
      expect(SpeedPitch.isLinked({'tempo': 0.0, 'pitch': 0.0}), isFalse);
    });

    test('unranged speed range is the tempo range, pitch stays legal', () {
      final r = SpeedPitch.speedRange(Presets.slowedReverb);
      expect(r, const ParameterRange(0.5, 1.5));
      final pitchDef = slideableDefinitionFor('pitch')!;
      expect(
        SpeedPitch.pitchFor(r.min),
        greaterThanOrEqualTo(pitchDef.min - 1e-9),
      );
      expect(SpeedPitch.pitchFor(r.max), lessThanOrEqualTo(pitchDef.max));
    });

    test('speed range narrows to keep the derived pitch in range', () {
      const p = EffectPreset(
        id: 'p',
        name: 'p',
        description: '',
        parameters: {},
        ranges: {'pitch': ParameterRange(-2.0, 2.0)},
      );
      final r = SpeedPitch.speedRange(p);
      expect(r.min, closeTo(math.pow(2, -2 / 12), 1e-12));
      expect(r.max, closeTo(math.pow(2, 2 / 12), 1e-12));
    });

    test('link clamps speed then derives pitch; values stay coupled', () {
      final l = SpeedPitch.link(Presets.lofi, 1.3);
      expect(l.tempo, 1.0);
      expect(l.pitch, 0.0);
      final m = SpeedPitch.link(Presets.slowedReverb, 0.8);
      expect(m.tempo, 0.8);
      expect(SpeedPitch.isLinked({'tempo': m.tempo, 'pitch': m.pitch}), isTrue);
    });

    test('repeated linking does not drift', () {
      var tempo = 0.83;
      for (var i = 0; i < 100; i++) {
        final l = SpeedPitch.link(Presets.slowedReverb, tempo);
        tempo = SpeedPitch.tempoFor(l.pitch);
      }
      expect(tempo, closeTo(0.83, 1e-9));
    });
  });

  test('slideable definitions cover every editor slider id once', () {
    final ids = slideableParameterDefinitions.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      ids,
      containsAll(['tempo', 'pitch', 'crackle', 'bassGain', 'phaserSpeedHz']),
    );
    expect(
      ids.length,
      effectParameterDefinitions.length +
          advancedReverbParameterDefinitions.length +
          4,
    );
  });
}
