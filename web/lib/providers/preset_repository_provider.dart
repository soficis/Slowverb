import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/data/repositories/preset_repository_web.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/preset_repository.dart';

/// Provider for the preset repository singleton.
final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  return PresetRepositoryWeb();
});

/// Provider for all custom presets.
/// Automatically refreshes when custom presets are added/deleted.
final customPresetsProvider = FutureProvider<List<EffectPreset>>((ref) async {
  final repo = ref.watch(presetRepositoryProvider);
  await repo.initialize();
  return repo.getAllCustomPresets();
});

/// Provider for all presets (built-in + custom).
/// Merges factory presets with user's custom presets.
final allPresetsProvider = FutureProvider<List<EffectPreset>>((ref) async {
  final customPresets = await ref.watch(customPresetsProvider.future);

  // Return built-in presets first, then custom presets
  return [...Presets.all, ...customPresets];
});
