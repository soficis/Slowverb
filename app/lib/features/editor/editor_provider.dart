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
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/domain/entities/project.dart';
import 'package:uuid/uuid.dart';

/// State for the current editing session
class EditorState {
  final Project? currentProject;
  final String? selectedPresetId;
  final Map<String, double> parameters;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isProcessing;
  final bool isExporting;
  final double exportProgress;
  final String? exportedFilePath;
  final String? errorMessage;
  final String? exportDirectory;
  final bool isGeneratingPreview;
  final String? previewFilePath;

  const EditorState({
    this.currentProject,
    this.selectedPresetId,
    this.parameters = const {},
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isProcessing = false,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportedFilePath,
    this.errorMessage,
    this.exportDirectory,
    this.isGeneratingPreview = false,
    this.previewFilePath,
  });

  EditorState copyWith({
    Project? currentProject,
    String? selectedPresetId,
    Map<String, double>? parameters,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isProcessing,
    bool? isExporting,
    double? exportProgress,
    String? exportedFilePath,
    String? errorMessage,
    String? exportDirectory,
    bool clearExportedFilePath = false,
    bool clearErrorMessage = false,
    bool? isGeneratingPreview,
    String? previewFilePath,
    bool clearPreviewFilePath = false,
  }) {
    return EditorState(
      currentProject: currentProject ?? this.currentProject,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      parameters: parameters ?? this.parameters,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isProcessing: isProcessing ?? this.isProcessing,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportedFilePath: clearExportedFilePath
          ? null
          : (exportedFilePath ?? this.exportedFilePath),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      exportDirectory: exportDirectory ?? this.exportDirectory,
      isGeneratingPreview: isGeneratingPreview ?? this.isGeneratingPreview,
      previewFilePath: clearPreviewFilePath
          ? null
          : (previewFilePath ?? this.previewFilePath),
    );
  }
}

/// Notifier managing the editor state and audio playback
class EditorNotifier extends StateNotifier<EditorState> {
  final AudioPlayer _audioPlayer;
  final Uuid _uuid = const Uuid();

  // Preview generation
  Timer? _previewDebounceTimer;
  String? _lastPreviewPath;
  static const _previewDebounceDuration = Duration(milliseconds: 500);

  EditorNotifier() : _audioPlayer = AudioPlayer(), super(const EditorState()) {
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
    _audioPlayer.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    _audioPlayer.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
  }

  /// Import an audio file and create a new project
  Future<bool> importAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return false;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        state = state.copyWith(errorMessage: 'Could not access file');
        return false;
      }

      // Get file info
      final fileName = path.basenameWithoutExtension(filePath);

      // Create a new project
      final project = Project(
        id: _uuid.v4(),
        name: fileName,
        sourcePath: filePath,
        sourceTitle: fileName,
        durationMs: 0,
        presetId: 'slowed_reverb',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Load the audio file to get duration
      await _audioPlayer.setFilePath(filePath);
      final duration = _audioPlayer.duration ?? Duration.zero;

      // Get default parameters from the preset
      final preset = Presets.slowedReverb;
      final defaultParams = <String, double>{};
      for (final param in preset.parameters) {
        defaultParams[param.id] = param.defaultValue;
      }

      state = state.copyWith(
        currentProject: project.copyWith(durationMs: duration.inMilliseconds),
        selectedPresetId: 'slowed_reverb',
        parameters: defaultParams,
        duration: duration,
        position: Duration.zero,
        isPlaying: false,
        clearExportedFilePath: true,
        clearPreviewFilePath: true,
      );

      // Generate initial preview with effects
      _schedulePreviewGeneration();

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to import: $e');
      return false;
    }
  }

  /// Schedule preview generation with debouncing
  void _schedulePreviewGeneration() {
    _previewDebounceTimer?.cancel();
    _previewDebounceTimer = Timer(_previewDebounceDuration, () {
      _generatePreviewWithEffects();
    });
  }

  /// Generate preview file with full FFmpeg effects
  Future<void> _generatePreviewWithEffects() async {
    final project = state.currentProject;
    if (project == null) return;

    // Check if FFmpeg is available
    final ffmpegPath = await _findFFmpeg();
    if (ffmpegPath == null) {
      // Fall back to basic tempo/pitch preview
      _applyBasicPlaybackEffects();
      return;
    }

    state = state.copyWith(isGeneratingPreview: true);

    try {
      // Create temp file for preview
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final previewPath = '${tempDir.path}/slowverb_preview_$timestamp.mp3';

      // Build filter chain (same as export)
      final filterChain = _buildFilterChain();

      // Remember current position and playback state
      final currentPosition = state.position;
      final wasPlaying = state.isPlaying;

      // Pause if playing to avoid audio issues during generation
      if (wasPlaying) {
        await _audioPlayer.pause();
      }

      // Run FFmpeg with optimized settings for speed
      final result = await Process.run(ffmpegPath, [
        '-y', // Overwrite
        '-i', project.sourcePath,
        '-af', filterChain,
        '-b:a', '128k', // Lower bitrate for speed
        '-threads', '0', // Use all CPU cores
        previewPath,
      ]);

      if (result.exitCode == 0) {
        // Clean up old preview file
        if (_lastPreviewPath != null) {
          try {
            await File(_lastPreviewPath!).delete();
          } catch (_) {}
        }
        _lastPreviewPath = previewPath;

        // Load the preview file - this resets position
        await _audioPlayer.setFilePath(previewPath);

        // CRITICAL: Wait for audio to be ready before seeking
        await Future.delayed(const Duration(milliseconds: 150));

        // Seek to same position (effects already in preview, no adjustment needed)
        if (currentPosition < (_audioPlayer.duration ?? Duration.zero)) {
          await _audioPlayer.seek(currentPosition);
          // Wait for seek operation to complete
          await Future.delayed(const Duration(milliseconds: 100));
        }

        state = state.copyWith(
          previewFilePath: previewPath,
          isGeneratingPreview: false,
          duration: _audioPlayer.duration ?? state.duration,
        );

        // Resume playback if was playing before
        if (wasPlaying) {
          await _audioPlayer.play();
        }
      } else {
        // Fall back to basic effects
        _applyBasicPlaybackEffects();
        state = state.copyWith(isGeneratingPreview: false);

        // Resume if was playing
        if (wasPlaying) {
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      // Fall back to basic effects
      _applyBasicPlaybackEffects();
      state = state.copyWith(isGeneratingPreview: false);
    }
  }

  /// Apply basic tempo/pitch effects (fallback when FFmpeg unavailable)
  void _applyBasicPlaybackEffects() {
    final tempo = state.parameters['tempo'] ?? 1.0;
    final pitch = state.parameters['pitch'] ?? 0.0;
    final pitchMultiplier = _semitonesToMultiplier(pitch);
    _audioPlayer.setSpeed(tempo);
    _audioPlayer.setPitch(pitchMultiplier);
  }

  double _semitonesToMultiplier(double semitones) {
    return 1.0 * (1.0 + (semitones * 0.05946));
  }

  /// Select a preset and update parameters to defaults
  void selectPreset(String presetId) {
    final preset = Presets.getById(presetId);
    if (preset == null) return;

    final defaultParams = <String, double>{};
    for (final param in preset.parameters) {
      defaultParams[param.id] = param.defaultValue;
    }

    state = state.copyWith(
      selectedPresetId: presetId,
      parameters: defaultParams,
    );

    if (state.currentProject != null) {
      state = state.copyWith(
        currentProject: state.currentProject!.copyWith(
          presetId: presetId,
          parameters: defaultParams,
        ),
      );
    }

    // Regenerate preview with new preset
    _schedulePreviewGeneration();
  }

  /// Update a single parameter value
  void updateParameter(String parameterId, double value) {
    final newParams = Map<String, double>.from(state.parameters);
    newParams[parameterId] = value;

    state = state.copyWith(parameters: newParams);

    if (state.currentProject != null) {
      state = state.copyWith(
        currentProject: state.currentProject!.copyWith(parameters: newParams),
      );
    }

    // Regenerate preview with debouncing
    _schedulePreviewGeneration();
  }

  /// Toggle play/pause
  Future<void> togglePlayback() async {
    if (state.isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Set custom export directory
  void setExportDirectory(String? directory) {
    state = state.copyWith(exportDirectory: directory);
  }

  /// Reset export state before starting new export
  void resetExportState() {
    state = state.copyWith(
      isExporting: false,
      exportProgress: 0.0,
      clearExportedFilePath: true,
      clearErrorMessage: true,
    );
  }

  /// Export the audio with effects applied using FFmpeg
  Future<bool> exportAudio({
    required String format,
    required String quality,
    String? customDirectory,
  }) async {
    final project = state.currentProject;
    if (project == null) return false;

    state = state.copyWith(
      isExporting: true,
      exportProgress: 0.0,
      clearExportedFilePath: true,
      clearErrorMessage: true,
    );

    try {
      // Get output directory
      Directory outputDir;
      if (customDirectory != null) {
        outputDir = Directory(customDirectory);
      } else if (state.exportDirectory != null) {
        outputDir = Directory(state.exportDirectory!);
      } else {
        final vDrive = Directory('V:\\Documents\\Slowverb');
        if (await Directory('V:\\').exists()) {
          outputDir = vDrive;
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          outputDir = Directory('${docsDir.path}\\Slowverb');
        }
      }

      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Generate output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final presetSuffix = _getPresetSuffix(state.selectedPresetId ?? 'custom');
      final outputPath =
          '${outputDir.path}/${project.name}_${presetSuffix}_$timestamp.$format';

      // Build FFmpeg filter chain
      final filterChain = _buildFilterChain();
      final bitrateArg = quality == 'high' ? '320k' : '128k';

      // Run FFmpeg export
      final ffmpegResult = await _runFFmpegExport(
        inputPath: project.sourcePath,
        outputPath: outputPath,
        filterChain: filterChain,
        format: format,
        bitrate: bitrateArg,
      );

      if (ffmpegResult) {
        state = state.copyWith(
          isExporting: false,
          exportProgress: 1.0,
          exportedFilePath: outputPath,
        );
        return true;
      } else {
        // Fallback: copy original file
        await File(project.sourcePath).copy(outputPath);
        state = state.copyWith(
          isExporting: false,
          exportProgress: 1.0,
          exportedFilePath: outputPath,
          errorMessage: 'FFmpeg not available. Exported original file.',
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Export failed: $e',
      );
      return false;
    }
  }

  String _getPresetSuffix(String presetId) {
    switch (presetId) {
      case 'slowed_reverb':
        return 'slowed_reverb';
      case 'vaporwave_chill':
        return 'vaporwave';
      case 'nightcore':
        return 'nightcore';
      case 'echo_slow':
        return 'echo';
      default:
        return 'custom';
    }
  }

  /// Build the FFmpeg filter chain
  String _buildFilterChain() {
    final tempo = state.parameters['tempo'] ?? 1.0;
    final pitch = state.parameters['pitch'] ?? 0.0;
    final reverbAmount = state.parameters['reverbAmount'] ?? 0.0;

    final filters = <String>[];

    // Pitch adjustment (48kHz sample rate)
    if (pitch != 0.0) {
      final multiplier = _semitonesToMultiplier(pitch);
      filters.add('asetrate=48000*$multiplier');
      filters.add('aresample=48000');
    }

    // Tempo adjustment
    if (tempo != 1.0) {
      filters.add('atempo=$tempo');
    }

    // Multi-stage reverb
    if (reverbAmount > 0) {
      filters.add('aecho=0.8:0.88:40|50|70:0.4|0.3|0.2');
    }

    // Bass enhancement
    if (reverbAmount > 0) {
      final bassGain = 5 + (reverbAmount * 5).toInt();
      filters.add('bass=g=$bassGain');
    }

    // Dynamic normalization
    filters.add('dynaudnorm=f=150:g=15');

    return filters.isEmpty ? 'anull' : filters.join(',');
  }

  /// Find FFmpeg executable
  Future<String?> _findFFmpeg() async {
    // Check bundled location first
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundledPath = '$exeDir/ffmpeg.exe';
    if (await File(bundledPath).exists()) {
      return bundledPath;
    }

    // Check scripts folder
    final scriptsPath = '$exeDir/../scripts/ffmpeg.exe';
    if (await File(scriptsPath).exists()) {
      return scriptsPath;
    }

    // Check system PATH
    try {
      final result = await Process.run(Platform.isWindows ? 'where' : 'which', [
        'ffmpeg',
      ]);
      if (result.exitCode == 0) {
        return 'ffmpeg';
      }
    } catch (_) {}

    return null;
  }

  /// Run FFmpeg export
  Future<bool> _runFFmpegExport({
    required String inputPath,
    required String outputPath,
    required String filterChain,
    required String format,
    required String bitrate,
  }) async {
    final ffmpegPath = await _findFFmpeg();
    if (ffmpegPath == null) return false;

    try {
      // Update progress
      state = state.copyWith(exportProgress: 0.1);

      final codecArgs = <String>[];
      if (format == 'mp3') {
        codecArgs.addAll(['-codec:a', 'libmp3lame', '-b:a', bitrate]);
      } else if (format == 'aac') {
        codecArgs.addAll(['-codec:a', 'aac', '-b:a', bitrate]);
      } else {
        codecArgs.addAll(['-codec:a', 'pcm_s16le']);
      }

      state = state.copyWith(exportProgress: 0.2);

      final result = await Process.run(ffmpegPath, [
        '-y',
        '-i',
        inputPath,
        '-af',
        filterChain,
        ...codecArgs,
        outputPath,
      ]);

      state = state.copyWith(exportProgress: 0.9);

      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Save current project
  Future<void> saveProject() async {
    if (state.currentProject == null) return;
    state = state.copyWith(
      currentProject: state.currentProject!.copyWith(
        updatedAt: DateTime.now(),
        parameters: state.parameters,
        presetId: state.selectedPresetId,
      ),
    );
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
  }

  /// Seek forward 10 seconds
  Future<void> seekForward() async {
    final currentPos = state.position;
    final duration = state.duration;
    final newPos = currentPos + const Duration(seconds: 10);
    if (newPos < duration) {
      await _audioPlayer.seek(newPos);
    } else {
      await _audioPlayer.seek(duration);
    }
  }

  /// Seek backward 10 seconds
  Future<void> seekBackward() async {
    final currentPos = state.position;
    final newPos = currentPos - const Duration(seconds: 10);
    if (newPos > Duration.zero) {
      await _audioPlayer.seek(newPos);
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  /// Reset parameters to preset defaults
  void resetToDefaults() {
    final presetId = state.selectedPresetId;
    if (presetId != null) {
      selectPreset(presetId);
    }
  }

  /// Clear the current project
  void clearProject() {
    _audioPlayer.stop();
    _previewDebounceTimer?.cancel();
    // Clean up preview file
    if (_lastPreviewPath != null) {
      try {
        File(_lastPreviewPath!).delete();
      } catch (_) {}
    }
    state = const EditorState();
  }

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _audioPlayer.dispose();
    // Clean up preview file
    if (_lastPreviewPath != null) {
      try {
        File(_lastPreviewPath!).delete();
      } catch (_) {}
    }
    super.dispose();
  }
}

/// Provider for the editor state
final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((
  ref,
) {
  return EditorNotifier();
});
