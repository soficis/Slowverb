/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/providers/waveform_provider.dart';

/// State for audio editor
class AudioEditorState {
  final String? audioFileName;
  final String? fileId;
  final AudioMetadata? metadata;
  final bool isLoading;
  final bool isPlaying;
  final double playbackPosition; // 0.0 to 1.0
  final EffectPreset selectedPreset;
  final Map<String, double> currentParameters;
  final String? error;

  const AudioEditorState({
    this.audioFileName,
    this.fileId,
    this.metadata,
    this.isLoading = false,
    this.isPlaying = false,
    this.playbackPosition = 0.0,
    required this.selectedPreset,
    required this.currentParameters,
    this.error,
  });

  Duration? get audioDuration => metadata?.duration;

  AudioEditorState copyWith({
    String? audioFileName,
    String? fileId,
    AudioMetadata? metadata,
    bool? isLoading,
    bool? isPlaying,
    double? playbackPosition,
    EffectPreset? selectedPreset,
    Map<String, double>? currentParameters,
    String? error,
  }) {
    return AudioEditorState(
      audioFileName: audioFileName ?? this.audioFileName,
      fileId: fileId ?? this.fileId,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      currentParameters: currentParameters ?? this.currentParameters,
      error: error,
    );
  }
}

/// Audio editor state notifier
class AudioEditorNotifier extends StateNotifier<AudioEditorState> {
  final Ref _ref;

  AudioEditorNotifier(this._ref)
    : super(
        AudioEditorState(
          selectedPreset: Presets.slowedReverb,
          currentParameters: Map.from(Presets.slowedReverb.parameters),
        ),
      );

  /// Load audio file
  Future<void> loadAudioFile(AudioFileData fileData) async {
    state = state.copyWith(
      isLoading: true,
      audioFileName: fileData.filename,
      error: null,
    );

    try {
      final engine = _ref.read(audioEngineProvider);

      // Generate unique file ID
      final fileId = 'file-${DateTime.now().millisecondsSinceEpoch}';

      // Load source into engine
      final metadata = await engine.loadSource(
        fileId: fileId,
        filename: fileData.filename,
        bytes: fileData.bytes,
      );

      state = state.copyWith(
        isLoading: false,
        fileId: fileId,
        metadata: metadata,
      );

      // Load waveform in background
      _ref.read(waveformProvider.notifier).loadWaveform(fileId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load audio: $e',
      );
    }
  }

  /// Apply preset
  void applyPreset(EffectPreset preset) {
    state = state.copyWith(
      selectedPreset: preset,
      currentParameters: Map.from(preset.parameters),
    );
  }

  /// Update single parameter
  void updateParameter(String key, double value) {
    final newParams = Map<String, double>.from(state.currentParameters);
    newParams[key] = value;
    state = state.copyWith(currentParameters: newParams);
  }

  /// Toggle playback
  void togglePlayback() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  /// Stop playback
  void stop() {
    state = state.copyWith(isPlaying: false, playbackPosition: 0.0);
  }

  /// Seek to position
  void seek(double position) {
    state = state.copyWith(playbackPosition: position);
  }

  /// Generate preview
  Future<Uri?> generatePreview() async {
    if (state.fileId == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final engine = _ref.read(audioEngineProvider);

      // Build effect config from current parameters
      final config = EffectConfig.fromParams(
        state.selectedPreset.id,
        state.currentParameters,
      );

      // Render 10-second preview
      final previewUri = await engine.renderPreview(
        fileId: state.fileId!,
        config: config,
        duration: const Duration(seconds: 10),
      );

      state = state.copyWith(isLoading: false);

      return previewUri;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate preview: $e',
      );
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for audio editor state
final audioEditorProvider =
    StateNotifierProvider<AudioEditorNotifier, AudioEditorState>((ref) {
      return AudioEditorNotifier(ref);
    });
