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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/providers/project_repository_provider.dart';
import 'package:slowverb_web/providers/waveform_provider.dart';
import 'package:uuid/uuid.dart';

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
  final String? projectId;
  final String? projectName;
  final DateTime? projectCreatedAt;
  final Object? fileHandle;

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
    this.projectId,
    this.projectName,
    this.projectCreatedAt,
    this.fileHandle,
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
    String? projectId,
    String? projectName,
    DateTime? projectCreatedAt,
    Object? fileHandle,
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
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      projectCreatedAt: projectCreatedAt ?? this.projectCreatedAt,
      fileHandle: fileHandle ?? this.fileHandle,
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
  Future<void> loadAudioFile(AudioFileData fileData, {Project? project}) async {
    final preset = project != null
        ? (Presets.getById(project.presetId) ?? Presets.slowedReverb)
        : Presets.slowedReverb;
    final initialParams = Map<String, double>.from(preset.parameters);
    if (project != null && project.parameters.isNotEmpty) {
      initialParams.addAll(project.parameters);
    }
    final now = DateTime.now();
    final projectId = project?.id ?? const Uuid().v4();
    final createdAt = project?.createdAt ?? now;

    state = state.copyWith(
      isLoading: true,
      audioFileName: fileData.filename,
      error: null,
      selectedPreset: preset,
      currentParameters: initialParams,
      projectId: projectId,
      projectName: project?.name ?? fileData.filename,
      projectCreatedAt: createdAt,
      fileHandle: fileData.fileHandle,
    );

    try {
      final engine = _ref.read(audioEngineProvider);
      final canLoad = await _allowLoad(engine, fileData);
      if (!canLoad) {
        return;
      }

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

      // Persist project snapshot with metadata
      unawaited(_persistProjectSnapshot());
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
    unawaited(_persistProjectSnapshot());
  }

  /// Update single parameter
  void updateParameter(String key, double value) {
    final newParams = Map<String, double>.from(state.currentParameters);
    newParams[key] = value;
    state = state.copyWith(currentParameters: newParams);
    unawaited(_persistProjectSnapshot());
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

      // Render full audio with effects applied
      final previewUri = await engine.renderPreview(
        fileId: state.fileId!,
        config: config,
        duration: state.metadata?.duration, // Process entire file
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

  /// Persist export metadata for the current project.
  Future<void> recordExport({
    required String format,
    int? bitrateKbps,
    String? path,
  }) async {
    final projectId = state.projectId;
    if (projectId == null) return;

    final repo = _ref.read(projectRepositoryProvider);
    await repo.initialize();

    final project = Project(
      id: projectId,
      name: state.projectName ?? state.audioFileName ?? 'Untitled',
      sourcePath: null,
      sourceHandleId: state.fileHandle != null ? projectId : null,
      sourceFileName: state.audioFileName,
      sourceTitle: null,
      sourceArtist: null,
      durationMs: state.metadata?.duration?.inMilliseconds ?? 0,
      presetId: state.selectedPreset.id,
      parameters: state.currentParameters,
      createdAt: state.projectCreatedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      lastExportPath: path,
      lastExportFormat: format,
      lastExportBitrateKbps: bitrateKbps,
      lastExportDate: DateTime.now(),
    );

    await repo.saveProject(project, fileHandle: state.fileHandle);
  }

  Future<void> _persistProjectSnapshot() async {
    final repo = _ref.read(projectRepositoryProvider);
    await repo.initialize();

    final projectId = state.projectId;
    if (projectId == null) return;

    final createdAt = state.projectCreatedAt ?? DateTime.now();
    if (state.projectCreatedAt == null) {
      state = state.copyWith(projectCreatedAt: createdAt);
    }

    final project = Project(
      id: projectId,
      name: state.projectName ?? state.audioFileName ?? 'Untitled',
      sourcePath: null,
      sourceHandleId: state.fileHandle != null ? projectId : null,
      sourceFileName: state.audioFileName,
      sourceTitle: null,
      sourceArtist: null,
      durationMs: state.metadata?.duration?.inMilliseconds ?? 0,
      presetId: state.selectedPreset.id,
      parameters: state.currentParameters,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );

    await repo.saveProject(project, fileHandle: state.fileHandle);
  }

  Future<bool> _allowLoad(AudioEngine engine, AudioFileData fileData) async {
    final preflight = await engine.checkMemoryPreflight(fileData.sizeBytes);
    if (preflight.isBlocked) {
      state = state.copyWith(isLoading: false, error: preflight.message);
      return false;
    }
    if (preflight.isWarning && preflight.message != null) {
      // ignore: avoid_print
      print('[AudioEditor] ${preflight.message}');
    }
    return true;
  }
}

/// Provider for audio editor state
final audioEditorProvider =
    StateNotifierProvider<AudioEditorNotifier, AudioEditorState>((ref) {
      return AudioEditorNotifier(ref);
    });
