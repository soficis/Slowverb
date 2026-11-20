import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:slowverb_web/data/repositories/preset_repository_web.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';

void main() {
  group('PresetRepositoryWeb', () {
    test('saves, loads, and deletes custom presets', () async {
      final repository = PresetRepositoryWeb(factory: newIdbFactoryMemory());
      await repository.initialize();

      const preset = EffectPreset(
        id: 'preset-1',
        name: 'Custom',
        description: 'Custom preset',
        parameters: {'tempo': 1.1, 'reverbAmount': 0.4},
      );

      await repository.saveCustomPreset(preset);
      expect(await repository.hasCustomPreset(preset.id), isTrue);

      final loaded = await repository.getCustomPreset(preset.id);
      expect(loaded, isNotNull);
      expect(loaded!.name, preset.name);

      await repository.deleteCustomPreset(preset.id);
      expect(await repository.hasCustomPreset(preset.id), isFalse);
    });

    test('round-trips per-preset parameter ranges', () async {
      final repository = PresetRepositoryWeb(factory: newIdbFactoryMemory());
      await repository.initialize();

      const ranged = EffectPreset(
        id: 'preset-ranged',
        name: 'Ranged',
        description: '',
        parameters: {'tempo': 0.8, 'reverbAmount': 0.3},
        ranges: {
          'tempo': ParameterRange(0.7, 0.95),
          'reverbAmount': ParameterRange(0.0, 0.5),
        },
      );
      const plain = EffectPreset(
        id: 'preset-plain',
        name: 'Plain',
        description: '',
        parameters: {'tempo': 1.0},
      );

      await repository.saveCustomPreset(ranged);
      await repository.saveCustomPreset(plain);

      final loadedRanged = await repository.getCustomPreset(ranged.id);
      final loadedPlain = await repository.getCustomPreset(plain.id);
      expect(loadedRanged!.ranges, ranged.ranges);
      expect(loadedPlain!.ranges, isEmpty);
    });
  });
}
