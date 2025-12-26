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
import 'package:slowverb_web/services/logger_service.dart';
import 'package:uuid/uuid.dart';

/// State for audio editor
class AudioEditorState {
  static const Object _noChange = Object();

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
  final Uri? currentPreviewUri;
  final bool isPreviewDirty;
  final bool
  previewMasteringApplied; // True if current preview was rendered with mastering

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

/// Audio editor state notifier
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

  void _initPlaybackListener() {
    final player = _ref.read(audioPlayerProvider);
    player.positionStream.listen((pos) {
      final audioDuration = state.metadata?.duration;
      if (audioDuration != null && audioDuration.inMilliseconds > 0) {
        final totalMs = audioDuration.inMilliseconds;
        final normalized = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);

        // Only update if changed significantly to avoid spamming state updates
        if ((normalized - state.playbackPosition).abs() > 0.001) {
          state = state.copyWith(playbackPosition: normalized);
        }
      }
    });

    // Also listen for player completion to reset position or handle looping
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false, playbackPosition: 0.0);
      }
    });
  }

  /// Listen for mastering settings changes and sync parameters map
  void _initMasteringListener() {
    // Listen to mastering settings changes and update parameters map
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
      // Reset preview dirty state on new load
      isPreviewDirty: true,
      currentPreviewUri: null,
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
    // Preserve mastering setting when applying presets - mastering is now managed separately
    final newParams = Map<String, double>.from(preset.parameters);
    // Copy mastering state from current parameters to preserve it
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

  /// Update single parameter with debounced preview generation.
  /// UI updates instantly for responsiveness, but preview generation is
  /// debounced to avoid excessive rendering during slider drag.
  void updateParameter(String key, double value) {
    // 1. Immediate UI update (optimistic update for slider responsiveness)
    final newParams = Map<String, double>.from(state.currentParameters);
    newParams[key] = value;
    if (key == 'masteringAlgorithm') {
      newParams['masteringMode'] = value >= 1.5 ? 5.0 : 3.0;
    }
    state = state.copyWith(currentParameters: newParams, isPreviewDirty: true);

    // 2. Debounce expensive preview generation and persistence
    _previewDebounce?.cancel();
    _previewDebounce = Timer(_debounceDuration, () {
      // Only persist after debounce completes
      unawaited(_persistProjectSnapshot());
    });
  }

  /// Toggle playback - renders effects and plays via just_audio.
  /// If the preview is already generated (isPreviewDirty=false) and cached,
  /// playback resumes instantly without re-rendering.
  Future<void> togglePlayback() async {
    _log.debug('togglePlayback called', {
      'fileId': state.fileId,
      'isPlaying': state.isPlaying,
    });
    if (state.fileId == null) {
      final message = state.isLoading
          ? 'Loading audio…'
          : 'No file loaded. Import a track first.';
      _log.debug(message);
      state = state.copyWith(error: message);
      return;
    }

    if (state.isLoading) {
      const message = 'Still processing… Please wait.';
      _log.debug(message);
      state = state.copyWith(error: message);
      return;
    }

    final playback = _ref.read(audioPlaybackProvider.notifier);

    if (state.isPlaying) {
      _log.debug('Stopping playback');
      await playback.stop();
      state = state.copyWith(isPlaying: false);
      return;
    }

    // Check if we can use cached preview (no re-rendering needed)
    if (!state.isPreviewDirty && state.currentPreviewUri != null) {
      _log.debug('Reusing cached preview', state.currentPreviewUri);
      try {
        await playback.playPreview(state.currentPreviewUri!);
        state = state.copyWith(isPlaying: true);
        _log.debug('Cached playback started');
      } catch (e, stack) {
        _log.error('Cached playback failed', e, stack);
        state = state.copyWith(isPlaying: false, error: 'Playback failed: $e');
      }
      return;
    }

    // Need to generate preview - show loading indicator
    try {
      state = state.copyWith(isLoading: true, error: null);

      _log.debug('Generating preview', {'dirty': state.isPreviewDirty});

      final previewUri = await generatePreview();
      if (previewUri != null) {
        _log.debug('Preview generated successfully', previewUri);
        // Track whether this preview was rendered with mastering
        final currentMasteringEnabled =
            (state.currentParameters['masteringEnabled'] ?? 0.0) > 0.5;
        state = state.copyWith(
          currentPreviewUri: previewUri,
          isPreviewDirty: false,
          previewMasteringApplied: currentMasteringEnabled,
        );

        _log.debug('Playing preview URI');
        await playback.playPreview(previewUri);
        state = state.copyWith(isPlaying: true, isLoading: false);
        _log.debug('Playback started');
      } else {
        _log.warning('generatePreview returned null');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to generate audio preview',
        );
      }
    } catch (e, stack) {
      _log.error('Playback failed', e, stack);
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'Playback failed: $e',
      );
    }
  }

  /// Regenerate preview with current settings.
  /// Stops playback if playing, marks preview as dirty, and generates fresh preview.
  ///
  /// If [resumeAtPosition] is true, seeks to the previous playback position after regeneration.
  Future<void> regenerate({bool resumeAtPosition = false}) async {
    _log.debug('Regenerate called', {'resumeAtPosition': resumeAtPosition});
    if (state.fileId == null) {
      _log.debug('No file loaded');
      return;
    }

    // Capture current position before stopping
    final previousPosition = resumeAtPosition ? state.playbackPosition : 0.0;
    _log.debug('Previous position', previousPosition);

    // Stop playback if currently playing
    if (state.isPlaying) {
      final playback = _ref.read(audioPlaybackProvider.notifier);
      await playback.stop();
      state = state.copyWith(isPlaying: false);
    }

    // Mark preview as dirty to force regeneration
    state = state.copyWith(isPreviewDirty: true, isLoading: true, error: null);

    try {
      _log.debug('Generating fresh preview');
      final previewUri = await generatePreview();
      if (previewUri != null) {
        _log.debug('Preview regenerated successfully', previewUri);
        // Track whether this preview was rendered with mastering
        final currentMasteringEnabled =
            (state.currentParameters['masteringEnabled'] ?? 0.0) > 0.5;
        state = state.copyWith(
          currentPreviewUri: previewUri,
          isPreviewDirty: false,
          previewMasteringApplied: currentMasteringEnabled,
        );

        // Automatically start playback of new preview
        _log.debug('Playing regenerated preview');
        final playback = _ref.read(audioPlaybackProvider.notifier);
        await playback.playPreview(previewUri);
        state = state.copyWith(isPlaying: true, isLoading: false);

        // Seek to previous position if requested
        if (resumeAtPosition && previousPosition > 0.0) {
          _log.debug('Seeking to previous position', previousPosition);
          seek(previousPosition);
        }

        _log.debug('Regenerated playback started');
      } else {
        _log.warning('Regeneration failed - preview URI is null');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to regenerate audio preview',
        );
      }
    } catch (e, stack) {
      _log.error('Regeneration failed', e, stack);
      state = state.copyWith(
        isLoading: false,
        isPlaying: false,
        error: 'Regeneration failed: $e',
      );
    }
  }

  /// Stop playback
  Future<void> stop() async {
    final playback = _ref.read(audioPlaybackProvider.notifier);
    await playback.stop();
    state = state.copyWith(isPlaying: false, playbackPosition: 0.0);
  }

  /// Seek to position
  void seek(double position) {
    state = state.copyWith(playbackPosition: position);

    final duration = state.metadata?.duration;
    if (duration != null && duration.inMilliseconds > 0) {
      final totalMs = duration.inMilliseconds;
      final seekPos = Duration(milliseconds: (position * totalMs).toInt());
      _ref.read(audioPlaybackProvider.notifier).seek(seekPos);
    }
  }

  /// Generate preview
  Future<Uri?> generatePreview() async {
    if (state.fileId == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final engine = _ref.read(audioEngineProvider);
      _log.debug('Reading engine provider', engine.runtimeType);

      // Build effect config from current parameters
      final config = EffectConfig.fromParams(
        state.selectedPreset.id,
        state.currentParameters,
      );
      _log.debug('Calling engine.renderPreview', state.currentParameters);

      // Render full audio with effects applied
      final previewUri = await engine.renderPreview(
        fileId: state.fileId!,
        config: config,
        duration: state.metadata?.duration, // Process entire file
      );

      _log.debug('Engine returned preview URI', previewUri);

      state = state.copyWith(isLoading: false);

      return previewUri;
    } catch (e, stack) {
      _log.error('generatePreview failed', e, stack);
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
      _log.info(preflight.message!);
    }
    return true;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }
}

/// Provider for audio editor state
final audioEditorProvider =
    StateNotifierProvider<AudioEditorNotifier, AudioEditorState>((ref) {
      return AudioEditorNotifier(ref);
    });
