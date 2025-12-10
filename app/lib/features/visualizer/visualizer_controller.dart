import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/domain/entities/visualizer_preset.dart';
import 'package:slowverb/domain/entities/waveform_data.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/services/waveform_analyzer.dart';

/// State indicating the currently active visualizer and analysis data
class VisualizerState {
  final VisualizerPreset activePreset;
  final AudioAnalysisFrame currentFrame;
  final WaveformData? waveformData;
  final bool isLoading;
  final bool isEnabled;

  const VisualizerState({
    required this.activePreset,
    required this.currentFrame,
    this.waveformData,
    this.isLoading = false,
    this.isEnabled = true,
  });

  VisualizerState copyWith({
    VisualizerPreset? activePreset,
    AudioAnalysisFrame? currentFrame,
    WaveformData? waveformData,
    bool? isLoading,
    bool? isEnabled,
  }) {
    return VisualizerState(
      activePreset: activePreset ?? this.activePreset,
      currentFrame: currentFrame ?? this.currentFrame,
      waveformData: waveformData ?? this.waveformData,
      isLoading: isLoading ?? this.isLoading,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Controller that drives the visualizer animation loop with real audio sync
class VisualizerController extends StateNotifier<VisualizerState> {
  final Ref ref;
  final WaveformAnalyzer _analyzer = WaveformAnalyzer();
  Ticker? _ticker;
  bool _isPlaying = false;
  double _time = 0.0;
  String? _currentSourcePath;

  static const _presets = [
    VisualizerPreset(
      id: 'wmp_retro',
      name: 'WMP Retro',
      description: 'Classic bars and waves',
      type: VisualizerType.wmpRetro,
    ),
    VisualizerPreset(
      id: 'starfield',
      name: 'Starfield',
      description: 'Windows 95 space travel',
      type: VisualizerType.starfield,
    ),
    VisualizerPreset(
      id: 'pipes_3d',
      name: '3D Pipes',
      description: 'Windows screensaver classic',
      type: VisualizerType.pipes3d,
    ),
    VisualizerPreset(
      id: 'maze_3d',
      name: '3D Maze',
      description: 'First-person maze journey',
      type: VisualizerType.maze3d,
    ),
  ];

  static List<VisualizerPreset> get presets => _presets;

  VisualizerController(this.ref)
    : super(
        VisualizerState(
          activePreset: _presets[0],
          currentFrame: AudioAnalysisFrame.empty(),
        ),
      ) {
    _startTicker();
    _listenToEditorState();
  }

  void _startTicker() {
    _ticker = Ticker(_onTick);
  }

  void _listenToEditorState() {
    // Listen for project changes to analyze new audio
    ref.listen(editorProvider.select((s) => s.currentProject?.sourcePath), (
      previous,
      next,
    ) {
      if (next != null && next != _currentSourcePath) {
        _analyzeNewSource(next);
      }
    });

    // Listen for position changes to sync visualization
    ref.listen(editorProvider.select((s) => s.position), (_, position) {
      _updateFrameFromPosition(position);
    });
  }

  Future<void> _analyzeNewSource(String sourcePath) async {
    _currentSourcePath = sourcePath;
    state = state.copyWith(isLoading: true);

    try {
      final waveform = await _analyzer.analyze(sourcePath);
      if (mounted && _currentSourcePath == sourcePath) {
        state = state.copyWith(waveformData: waveform, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void _updateFrameFromPosition(Duration position) {
    final waveform = state.waveformData;
    if (waveform == null || waveform.isEmpty) return;

    // Get spectrum-like bands from waveform at current position
    final bands = waveform.getSpectrumSlice(position, bandCount: 32);
    final level = waveform.getLevelAtPosition(position);

    state = state.copyWith(
      currentFrame: AudioAnalysisFrame(magnitudes: bands, level: level),
    );
  }

  void setPlaying(bool isPlaying) {
    _isPlaying = isPlaying;
    if (_isPlaying) {
      if (!(_ticker?.isActive ?? false)) {
        _ticker?.start();
      }
    }
  }

  void selectPreset(String id) {
    final preset = _presets.firstWhere(
      (p) => p.id == id,
      orElse: () => _presets[0],
    );
    state = state.copyWith(activePreset: preset);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    _time = elapsed.inMilliseconds / 1000.0;

    if (!_isPlaying) {
      // Decay to silence when paused
      final currentLevel = state.currentFrame.level;
      if (currentLevel > 0.01) {
        state = state.copyWith(
          currentFrame: AudioAnalysisFrame(
            magnitudes: List.filled(32, 0.0),
            level: currentLevel * 0.9,
          ),
        );
      }
      return;
    }

    // If we don't have waveform data yet, use simulated data
    if (state.waveformData == null || state.waveformData!.isEmpty) {
      _generateSimulatedFrame();
    }
  }

  void _generateSimulatedFrame() {
    final random = Random();
    final bands = List<double>.generate(32, (i) {
      final base = sin(_time * 2 + i * 0.2) * 0.5 + 0.5;
      final fast = cos(_time * 8 + i * 0.5) * 0.3;
      final noise = random.nextDouble() * 0.1;
      final bias = 1.0 - (i / 32.0);
      return ((base + fast + noise) * bias).clamp(0.0, 1.0);
    });

    final level = bands.reduce((a, b) => a + b) / bands.length * 2.0;

    state = state.copyWith(
      currentFrame: AudioAnalysisFrame(
        magnitudes: bands,
        level: level.clamp(0.0, 1.0),
      ),
    );
  }

  double get currentTime => _time;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

final visualizerProvider =
    StateNotifierProvider<VisualizerController, VisualizerState>((ref) {
      return VisualizerController(ref);
    });
