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
  });
}
