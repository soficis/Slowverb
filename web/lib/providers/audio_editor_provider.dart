import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';
import 'package:slowverb_web/providers/project_repository_provider.dart';
import 'package:slowverb_web/providers/settings_provider.dart';
import 'package:slowverb_web/providers/waveform_provider.dart';
import 'package:slowverb_web/providers/processing_progress_provider.dart';
import 'package:slowverb_web/services/logger_service.dart';
import 'package:uuid/uuid.dart';
part 'audio_editor_provider_impl.dart';

class AudioEditorState {
  static const Object _noChange = Object();

  final String? audioFileName;
  final String? fileId;
  final AudioMetadata? metadata;
  final bool isLoading;
  final bool isPlaying;
  final double playbackPosition;
  final EffectPreset selectedPreset;
  final Map<String, double> currentParameters;
  final String? error;
  final String? projectId;
  final String? projectName;
  final DateTime? projectCreatedAt;
  final Object? fileHandle;
  final Uri? currentPreviewUri;
  final bool isPreviewDirty;
  final bool previewMasteringApplied;

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
    this.currentPreviewUri,
    this.isPreviewDirty = true,
    this.previewMasteringApplied = false,
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
    Object? error = _noChange,
    String? projectId,
    String? projectName,
    DateTime? projectCreatedAt,
    Object? fileHandle,
    Uri? currentPreviewUri,
    bool? isPreviewDirty,
    bool? previewMasteringApplied,
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
      error: identical(error, _noChange) ? this.error : error as String?,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      projectCreatedAt: projectCreatedAt ?? this.projectCreatedAt,
      fileHandle: fileHandle ?? this.fileHandle,
      currentPreviewUri: currentPreviewUri ?? this.currentPreviewUri,
      isPreviewDirty: isPreviewDirty ?? this.isPreviewDirty,
      previewMasteringApplied:
          previewMasteringApplied ?? this.previewMasteringApplied,
    );
  }
}

class AudioEditorNotifier extends StateNotifier<AudioEditorState> {
  final Ref _ref;
  Timer? _previewDebounce;
  static const _debounceDuration = Duration(milliseconds: 400);
  static const _log = SlowverbLogger('AudioEditor');

  AudioEditorNotifier(this._ref)
    : super(
        AudioEditorState(
          selectedPreset: Presets.slowedReverb,
          currentParameters: () {
            final params = Map<String, double>.from(
              Presets.slowedReverb.parameters,
            );
            // Initialize mastering from persistent settings
            final masteringSettings = _ref.read(masteringSettingsProvider);
            params['masteringEnabled'] = masteringSettings.masteringEnabled
                ? 1.0
                : 0.0;
            params['masteringAlgorithm'] = masteringSettings.phaselimiterEnabled
                ? (masteringSettings.mode >= 5 ? 2.0 : 1.0)
                : 0.0;
            params['masteringTargetLufs'] = masteringSettings.targetLufs;
            params['masteringBassPreservation'] =
                masteringSettings.bassPreservation;
            params['masteringMode'] = masteringSettings.mode.toDouble();
            return params;
          }(),
        ),
      ) {
    _initPlaybackListener();
    _initMasteringListener();
  }

  AudioEditorState get editorState => state;

  set editorState(AudioEditorState value) => state = value;

  void _initPlaybackListener() {
    final player = _ref.read(audioPlayerProvider);
    player.positionStream.listen((pos) {
      final totalDuration = player.duration ?? state.metadata?.duration;

      if (totalDuration != null && totalDuration.inMilliseconds > 0) {
        final totalMs = totalDuration.inMilliseconds;
        final normalized = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

        if ((normalized - state.playbackPosition).abs() > 0.001) {
          state = state.copyWith(playbackPosition: normalized);
        }
      }
    });

    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false, playbackPosition: 0.0);
      }
    });
  }

  void _initMasteringListener() {
    _ref.listen<MasteringSettings>(masteringSettingsProvider, (_, next) {
      final newParams = Map<String, double>.from(state.currentParameters);
      newParams['masteringEnabled'] = next.masteringEnabled ? 1.0 : 0.0;
      newParams['masteringAlgorithm'] = next.phaselimiterEnabled
          ? (next.mode >= 5 ? 2.0 : 1.0)
          : 0.0;
      newParams['masteringTargetLufs'] = next.targetLufs;
      newParams['masteringBassPreservation'] = next.bassPreservation;
      newParams['masteringMode'] = next.mode.toDouble();
      state = state.copyWith(
        currentParameters: newParams,
        isPreviewDirty: true,
      );
    });
  }

  /// Load audio file
  Future<void> loadAudioFile(AudioFileData fileData, {Project? project}) =>
      loadAudioFileImpl(this, fileData, project: project);

  void applyPreset(EffectPreset preset) {
    final newParams = Map<String, double>.from(preset.parameters);
    newParams['masteringEnabled'] =
        state.currentParameters['masteringEnabled'] ?? 0.0;
    newParams['masteringAlgorithm'] =
        state.currentParameters['masteringAlgorithm'] ?? 0.0;
    newParams['masteringTargetLufs'] =
        state.currentParameters['masteringTargetLufs'] ?? -14.0;
    newParams['masteringBassPreservation'] =
        state.currentParameters['masteringBassPreservation'] ?? 0.5;
    newParams['masteringMode'] =
        state.currentParameters['masteringMode'] ?? 5.0;

    state = state.copyWith(
      selectedPreset: preset,
      currentParameters: newParams,
      isPreviewDirty: true,
    );
    unawaited(_persistProjectSnapshot());
  }

  void updateParameter(String key, double value) {
    final newParams = Map<String, double>.from(state.currentParameters);
    newParams[key] = value;
    if (key == 'masteringAlgorithm') {
      newParams['masteringMode'] = value >= 1.5 ? 5.0 : 3.0;
    }
    state = state.copyWith(currentParameters: newParams, isPreviewDirty: true);

    _previewDebounce?.cancel();
    _previewDebounce = Timer(_debounceDuration, () {
      unawaited(_persistProjectSnapshot());
    });
  }

  Future<void> togglePlayback() async {
    await togglePlaybackImpl(this);
  }

  Future<void> regenerate({bool resumeAtPosition = false}) async {
    await regenerateImpl(this, resumeAtPosition: resumeAtPosition);
  }

  Future<void> stop() async {
    final playback = _ref.read(audioPlaybackProvider.notifier);
    await playback.stop();
    state = state.copyWith(isPlaying: false, playbackPosition: 0.0);
  }

  void seek(double position) {
    state = state.copyWith(playbackPosition: position);

    final duration = state.metadata?.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      final totalMs = duration.inMilliseconds;
      final seekPos = Duration(milliseconds: (position * totalMs).toInt());
      _ref.read(audioPlaybackProvider.notifier).seek(seekPos);
    }
  }

  Future<Uri?> generatePreview() async {
    return generatePreviewImpl(this);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void forceStop() {
    _previewDebounce?.cancel();
    state = state.copyWith(isLoading: false, isPlaying: false, error: null);
    _ref.read(audioPlaybackProvider.notifier).stop();
  }

  Future<void> recordExport({
    required String format,
    int? bitrateKbps,
    String? path,
  }) => recordExportImpl(
    this,
    format: format,
    bitrateKbps: bitrateKbps,
    path: path,
  );
  Future<void> _persistProjectSnapshot() async {
    await persistProjectSnapshotImpl(this);
  }

  Future<bool> _allowLoad(AudioEngine engine, AudioFileData fileData) =>
      allowLoadImpl(this, engine, fileData);
  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }
}

final audioEditorProvider =
    StateNotifierProvider<AudioEditorNotifier, AudioEditorState>((ref) {
      return AudioEditorNotifier(ref);
    });
