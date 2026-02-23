import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/parameter_definitions.dart';

void main() {
  group('ParameterDefinition', () {
    test('effectParameterDefinitions contains expected parameters', () {
      expect(effectParameterDefinitions.length, 5);

      final ids = effectParameterDefinitions.map((p) => p.id).toList();
      expect(ids, contains('tempo'));
      expect(ids, contains('pitch'));
      expect(ids, contains('reverbAmount'));
      expect(ids, contains('echoAmount'));
      expect(ids, contains('eqWarmth'));
    });

    test('tempo parameter has correct range', () {
      final tempo = effectParameterDefinitions.firstWhere(
        (p) => p.id == 'tempo',
      );
      expect(tempo.label, 'Tempo');
      expect(tempo.min, 0.5);
      expect(tempo.max, 1.5);
      expect(tempo.defaultValue, 1.0);
    });

    test('pitch parameter has correct range', () {
      final pitch = effectParameterDefinitions.firstWhere(
        (p) => p.id == 'pitch',
      );
      expect(pitch.label, 'Pitch');
      expect(pitch.min, -12.0);
      expect(pitch.max, 12.0);
      expect(pitch.defaultValue, 0.0);
    });

    test('reverb parameter has correct range', () {
      final reverb = effectParameterDefinitions.firstWhere(
        (p) => p.id == 'reverbAmount',
      );
      expect(reverb.label, 'Reverb');
      expect(reverb.min, 0.0);
      expect(reverb.max, 1.0);
      expect(reverb.defaultValue, 0.0);
    });

    test('echo parameter has correct range', () {
      final echo = effectParameterDefinitions.firstWhere(
        (p) => p.id == 'echoAmount',
      );
      expect(echo.label, 'Echo');
      expect(echo.min, 0.0);
      expect(echo.max, 1.0);
      expect(echo.defaultValue, 0.0);
    });

    test('warmth parameter has correct range', () {
      final warmth = effectParameterDefinitions.firstWhere(
        (p) => p.id == 'eqWarmth',
      );
      expect(warmth.label, 'Warmth');
      expect(warmth.min, 0.0);
      expect(warmth.max, 1.0);
      expect(warmth.defaultValue, 0.5);
    });
  });

  group('Constants', () {
    test('seekStepMs is 10 seconds', () {
      expect(seekStepMs, 10000);
    });
  });
}
