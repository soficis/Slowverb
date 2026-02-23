part of 'audio_editor_provider.dart';

Future<void> loadAudioFileImpl(
  AudioEditorNotifier notifier,
  AudioFileData fileData, {
  Project? project,
}) async {
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

  notifier.editorState = notifier.editorState.copyWith(
    isLoading: true,
    audioFileName: fileData.filename,
    error: null,
    selectedPreset: preset,
    currentParameters: initialParams,
    projectId: projectId,
    projectName: project?.name ?? fileData.filename,
    projectCreatedAt: createdAt,
    fileHandle: fileData.fileHandle,
    isPreviewDirty: true,
    currentPreviewUri: null,
  );

  try {
    final engine = notifier._ref.read(audioEngineProvider);
    final canLoad = await notifier._allowLoad(engine, fileData);
    if (!canLoad) {
      return;
    }

    final fileId = 'file-${DateTime.now().millisecondsSinceEpoch}';
    final metadata = await engine.loadSource(
      fileId: fileId,
      filename: fileData.filename,
      bytes: fileData.bytes,
    );

    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      fileId: fileId,
      metadata: metadata,
    );

    notifier._ref.read(waveformProvider.notifier).loadWaveform(fileId);
    unawaited(notifier._persistProjectSnapshot());
  } catch (e) {
    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      error: 'Failed to load audio: $e',
    );
  }
}

Future<void> togglePlaybackImpl(AudioEditorNotifier notifier) async {
  AudioEditorNotifier._log.debug('togglePlayback called', {
    'fileId': notifier.editorState.fileId,
    'isPlaying': notifier.editorState.isPlaying,
  });

  if (notifier.editorState.fileId == null) {
    final message = notifier.editorState.isLoading
        ? 'Loading audio…'
        : 'No file loaded. Import a track first.';
    AudioEditorNotifier._log.debug(message);
    notifier.editorState = notifier.editorState.copyWith(error: message);
    return;
  }

  if (notifier.editorState.isLoading) {
    const message = 'Still processing… Please wait.';
    AudioEditorNotifier._log.debug(message);
    notifier.editorState = notifier.editorState.copyWith(error: message);
    return;
  }

  final playback = notifier._ref.read(audioPlaybackProvider.notifier);

  if (notifier.editorState.isPlaying) {
    AudioEditorNotifier._log.debug('Stopping playback');
    await playback.stop();
    notifier.editorState = notifier.editorState.copyWith(isPlaying: false);
    return;
  }

  if (!notifier.editorState.isPreviewDirty && notifier.editorState.currentPreviewUri != null) {
    AudioEditorNotifier._log.debug('Reusing cached preview', notifier.editorState.currentPreviewUri);
    try {
      await playback.playPreview(notifier.editorState.currentPreviewUri!);
      notifier.editorState = notifier.editorState.copyWith(isPlaying: true);
      AudioEditorNotifier._log.debug('Cached playback started');
    } catch (e, stack) {
      AudioEditorNotifier._log.error('Cached playback failed', e, stack);
      notifier.editorState = notifier.editorState.copyWith(isPlaying: false, error: 'Playback failed: $e');
    }
    return;
  }

  try {
    notifier.editorState = notifier.editorState.copyWith(isLoading: true, error: null);

    final engine = notifier._ref.read(audioEngineProvider);
    await engine.resumeAudioContext();

    AudioEditorNotifier._log.debug('Generating preview', {'dirty': notifier.editorState.isPreviewDirty});

    final previewUri = await notifier.generatePreview();
    if (previewUri != null) {
      AudioEditorNotifier._log.debug('Preview generated successfully', previewUri);
      final currentMasteringEnabled =
          (notifier.editorState.currentParameters['masteringEnabled'] ?? 0.0) > 0.5;
      notifier.editorState = notifier.editorState.copyWith(
        currentPreviewUri: previewUri,
        isPreviewDirty: false,
        previewMasteringApplied: currentMasteringEnabled,
      );

      AudioEditorNotifier._log.debug('Playing preview URI');
      await playback.playPreview(previewUri);
      notifier.editorState = notifier.editorState.copyWith(isPlaying: true, isLoading: false);
      AudioEditorNotifier._log.debug('Playback started');
    } else {
      AudioEditorNotifier._log.warning('generatePreview returned null');
      notifier.editorState = notifier.editorState.copyWith(
        isLoading: false,
        error: 'Failed to generate audio preview',
      );
    }
  } catch (e, stack) {
    AudioEditorNotifier._log.error('Playback failed', e, stack);
    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      isPlaying: false,
      error: 'Playback failed: $e',
    );
  }
}

Future<void> regenerateImpl(
  AudioEditorNotifier notifier, {
  required bool resumeAtPosition,
}) async {
  AudioEditorNotifier._log.debug(
    'Regenerate called',
    {'resumeAtPosition': resumeAtPosition},
  );
  if (notifier.editorState.fileId == null) {
    AudioEditorNotifier._log.debug('No file loaded');
    return;
  }

  final previousPosition = resumeAtPosition ? notifier.editorState.playbackPosition : 0.0;
  AudioEditorNotifier._log.debug('Previous position', previousPosition);

  if (notifier.editorState.isPlaying) {
    final playback = notifier._ref.read(audioPlaybackProvider.notifier);
    await playback.stop();
    notifier.editorState = notifier.editorState.copyWith(isPlaying: false);
  }

  notifier.editorState = notifier.editorState.copyWith(
    isPreviewDirty: true,
    isLoading: true,
    error: null,
  );

  try {
    final engine = notifier._ref.read(audioEngineProvider);
    await engine.resumeAudioContext();

    AudioEditorNotifier._log.debug('Generating fresh preview');
    final previewUri = await notifier.generatePreview();
    if (previewUri != null) {
      AudioEditorNotifier._log.debug('Preview regenerated successfully', previewUri);
      final currentMasteringEnabled =
          (notifier.editorState.currentParameters['masteringEnabled'] ?? 0.0) > 0.5;
      notifier.editorState = notifier.editorState.copyWith(
        currentPreviewUri: previewUri,
        isPreviewDirty: false,
        previewMasteringApplied: currentMasteringEnabled,
      );

      AudioEditorNotifier._log.debug('Playing regenerated preview');
      final playback = notifier._ref.read(audioPlaybackProvider.notifier);
      await playback.playPreview(previewUri);
      notifier.editorState = notifier.editorState.copyWith(isPlaying: true, isLoading: false);

      if (resumeAtPosition && previousPosition > 0.0) {
        AudioEditorNotifier._log.debug('Seeking to previous position', previousPosition);
        notifier.seek(previousPosition);
      }

      AudioEditorNotifier._log.debug('Regenerated playback started');
    } else {
      AudioEditorNotifier._log.warning('Regeneration failed - preview URI is null');
      notifier.editorState = notifier.editorState.copyWith(
        isLoading: false,
        error: 'Failed to regenerate audio preview',
      );
    }
  } catch (e, stack) {
    AudioEditorNotifier._log.error('Regeneration failed', e, stack);
    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      isPlaying: false,
      error: 'Regeneration failed: $e',
    );
  }
}

Future<Uri?> generatePreviewImpl(AudioEditorNotifier notifier) async {
  if (notifier.editorState.fileId == null) return null;

  notifier.editorState = notifier.editorState.copyWith(isLoading: true, error: null);

  final masteringMode = notifier.editorState.currentParameters['masteringMode'] ?? 3.0;
  final masteringEnabled =
      (notifier.editorState.currentParameters['masteringEnabled'] ?? 0.0) > 0.5;
  final isLevel5 = masteringEnabled && masteringMode >= 5;

  final progressNotifier = notifier._ref.read(processingProgressProvider.notifier);
  progressNotifier.startProcessing(isLevel5: isLevel5);

  try {
    final engine = notifier._ref.read(audioEngineProvider);
    AudioEditorNotifier._log.debug('Reading engine provider', engine.runtimeType);

    engine.setPreviewProgressCallback((progress, stage) {
      progressNotifier.updateProgress(progress, stage);
    });
    engine.setWarningCallback((message) {
      notifier.editorState = notifier.editorState.copyWith(error: message);
    });

    final config = EffectConfig.fromParams(
      notifier.editorState.selectedPreset.id,
      notifier.editorState.currentParameters,
    );
    AudioEditorNotifier._log.debug('Calling engine.renderPreview', notifier.editorState.currentParameters);

    final previewUri = await engine.renderPreview(
      fileId: notifier.editorState.fileId!,
      config: config,
      duration: notifier.editorState.metadata?.duration,
    );

    AudioEditorNotifier._log.debug('Engine returned preview URI', previewUri);

    notifier.editorState = notifier.editorState.copyWith(isLoading: false);
    progressNotifier.complete();

    engine.setPreviewProgressCallback(null);
    engine.setWarningCallback(null);

    return previewUri;
  } catch (e, stack) {
    AudioEditorNotifier._log.error('generatePreview failed', e, stack);

    notifier._ref.read(processingProgressProvider.notifier).cancel();

    final audioEngine = notifier._ref.read(audioEngineProvider);
    audioEngine.setPreviewProgressCallback(null);
    audioEngine.setWarningCallback(null);

    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      error: 'Failed to generate preview: $e',
    );
    return null;
  }
}

Future<void> persistProjectSnapshotImpl(AudioEditorNotifier notifier) async {
  final repo = notifier._ref.read(projectRepositoryProvider);
  await repo.initialize();

  final projectId = notifier.editorState.projectId;
  if (projectId == null) return;

  final createdAt = notifier.editorState.projectCreatedAt ?? DateTime.now();
  if (notifier.editorState.projectCreatedAt == null) {
    notifier.editorState = notifier.editorState.copyWith(projectCreatedAt: createdAt);
  }

  final project = Project(
    id: projectId,
    name: notifier.editorState.projectName ?? notifier.editorState.audioFileName ?? 'Untitled',
    sourcePath: null,
    sourceHandleId: notifier.editorState.fileHandle != null ? projectId : null,
    sourceFileName: notifier.editorState.audioFileName,
    sourceTitle: null,
    sourceArtist: null,
    durationMs: notifier.editorState.metadata?.duration?.inMilliseconds ?? 0,
    presetId: notifier.editorState.selectedPreset.id,
    parameters: notifier.editorState.currentParameters,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  await repo.saveProject(project, fileHandle: notifier.editorState.fileHandle);
}

Future<void> recordExportImpl(
  AudioEditorNotifier notifier, {
  required String format,
  int? bitrateKbps,
  String? path,
}) async {
  final projectId = notifier.editorState.projectId;
  if (projectId == null) return;

  final repo = notifier._ref.read(projectRepositoryProvider);
  await repo.initialize();

  final project = Project(
    id: projectId,
    name: notifier.editorState.projectName ?? notifier.editorState.audioFileName ?? 'Untitled',
    sourcePath: null,
    sourceHandleId: notifier.editorState.fileHandle != null ? projectId : null,
    sourceFileName: notifier.editorState.audioFileName,
    sourceTitle: null,
    sourceArtist: null,
    durationMs: notifier.editorState.metadata?.duration?.inMilliseconds ?? 0,
    presetId: notifier.editorState.selectedPreset.id,
    parameters: notifier.editorState.currentParameters,
    createdAt: notifier.editorState.projectCreatedAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
    lastExportPath: path,
    lastExportFormat: format,
    lastExportBitrateKbps: bitrateKbps,
    lastExportDate: DateTime.now(),
  );

  await repo.saveProject(project, fileHandle: notifier.editorState.fileHandle);
}

Future<bool> allowLoadImpl(
  AudioEditorNotifier notifier,
  AudioEngine engine,
  AudioFileData fileData,
) async {
  final preflight = await engine.checkMemoryPreflight(fileData.sizeBytes);
  if (preflight.isBlocked) {
    notifier.editorState = notifier.editorState.copyWith(
      isLoading: false,
      error: preflight.message,
    );
    return false;
  }
  if (preflight.isWarning && preflight.message != null) {
    AudioEditorNotifier._log.info(preflight.message!);
  }
  return true;
}
