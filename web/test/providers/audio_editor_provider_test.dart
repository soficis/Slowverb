import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';

void main() {
  group('AudioEditorState', () {
    test('copyWith updates preview state fields deterministically', () {
      final initial = AudioEditorState(
        selectedPreset: Presets.slowedReverb,
        currentParameters: Map<String, double>.from(Presets.slowedReverb.parameters),
      );

      final updated = initial.copyWith(
        isLoading: true,
        isPreviewDirty: false,
        previewMasteringApplied: true,
      );

      expect(updated.isLoading, isTrue);
      expect(updated.isPreviewDirty, isFalse);
      expect(updated.previewMasteringApplied, isTrue);
      expect(updated.selectedPreset.id, initial.selectedPreset.id);
    });

    test('copyWith can explicitly clear error', () {
      const initial = AudioEditorState(
        selectedPreset: Presets.slowedReverb,
        currentParameters: {'tempo': 1.0},
        error: 'Failed',
      );

      final cleared = initial.copyWith(error: null);
      expect(cleared.error, isNull);
    });
  });
}
