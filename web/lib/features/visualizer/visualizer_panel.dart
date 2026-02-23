import 'dart:async';
import 'dart:math' show sin, cos, pi, max, min, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
part 'visualizer_panel_painters_a.dart';
part 'visualizer_panel_painters_b.dart';
part 'visualizer_panel_painters_c.dart';

/// Provides loaded GPU shaders for visualizers.
/// Returns map with successfully loaded shaders, CPU fallback for failed ones.
final webShaderProvider = FutureProvider<Map<String, ui.FragmentProgram>>((
  ref,
) async {
  final shaders = <String, ui.FragmentProgram>{};

  // Load each shader individually so one failure doesn't break all
  final shaderPaths = {
    'wmp_retro': 'shaders/wmp_retro.frag',
    'starfield_warp': 'shaders/starfield.frag',
    'pipes_vaporwave': 'shaders/pipes_3d.frag',
    'maze_neon': 'shaders/maze_3d.frag',
    'time_gate': 'shaders/time_gate.frag',
    'rainy_window_3d': 'shaders/rainy_window_3d.frag',
    'fractal_dreams_3d': 'shaders/fractal_dreams_3d.frag',
    'vortex': 'shaders/vortex.frag',
  };

  for (final entry in shaderPaths.entries) {
    try {
      final shader = await ui.FragmentProgram.fromAsset(entry.value);
      shaders[entry.key] = shader;
    } catch (e) {
      debugPrint('Failed to load shader ${entry.key}: $e');
      // Continue loading other shaders
    }
  }

  debugPrint('Loaded ${shaders.length}/${shaderPaths.length} GPU shaders');
  return shaders;
});

/// Rendering mode indicator
enum VisualizerRenderMode { gpu, cpu, loading }

/// Web-optimized visualizer panel with GPU-accelerated shaders and CPU fallback.
/// Uses FragmentProgram for GPU rendering via CanvasKit/WebGL.
class VisualizerPanel extends ConsumerStatefulWidget {
  final Stream<AudioAnalysisFrame>? analysisStream;
  final VisualizerPreset? preset;
  final double? height;
  final bool isPlaying;
  final VoidCallback? onDoubleTap;
  final bool isFullscreen;

  const VisualizerPanel({
    super.key,
    this.analysisStream,
    this.preset,
    this.height,
    this.isPlaying = false,
    this.onDoubleTap,
    this.isFullscreen = false,
  });

  @override
  ConsumerState<VisualizerPanel> createState() => _VisualizerPanelState();
}

class _VisualizerPanelState extends ConsumerState<VisualizerPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<AudioAnalysisFrame>? _sub;
  AudioAnalysisFrame _currentFrame = AudioAnalysisFrame.empty();
  double _time = 0;

  // Frame rate throttling
  final Stopwatch _fpsWatch = Stopwatch();
  int _frameCount = 0;
  double _currentFps = 60;
  int _targetFps = 60;
  int _frameSkip = 0;

  // Idle frame skipping for battery/CPU savings
  int _idleFrameCounter = 0;
  static const int _idleFrameSkip =
      2; // Skip every other frame when idle (~20fps)

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);

    // Always animate the visualizer for visual appeal
    _controller.repeat();
    _subscribeToAnalysis();
    _fpsWatch.start();
  }

  @override
  void didUpdateWidget(covariant VisualizerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisStream != oldWidget.analysisStream) {
      _subscribeToAnalysis();
    }
    // Reset idle frame counter on playback state change
    if (widget.isPlaying != oldWidget.isPlaying) {
      _idleFrameCounter = 0;
    }
    // Keep animation running always - visualizers should always be alive
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _tick() {
    // Idle framerate reduction: skip frames when audio is not playing
    if (!widget.isPlaying) {
      _idleFrameCounter++;
      if (_idleFrameCounter % _idleFrameSkip != 0) {
        return; // Skip this frame
      }
    } else {
      _idleFrameCounter = 0; // Reset when playing
    }
    // Frame rate measurement and throttling
    _frameCount++;
    if (_fpsWatch.elapsedMilliseconds >= 1000) {
      _currentFps = _frameCount * 1000 / _fpsWatch.elapsedMilliseconds;
      _frameCount = 0;
      _fpsWatch.reset();
      _fpsWatch.start();

      // Adaptive throttling: reduce to 30 FPS if struggling
      if (_currentFps < 45 && _targetFps == 60) {
        _targetFps = 30;
        _frameSkip = 1; // Skip every other frame
      } else if (_currentFps > 55 && _targetFps == 30) {
        _targetFps = 60;
        _frameSkip = 0;
      }
    }

    // Skip frames if throttling
    if (_frameSkip > 0 && _frameCount % (_frameSkip + 1) != 0) {
      return;
    }

    setState(() {
      _time += _targetFps == 60 ? 0.016 : 0.033;
    });
  }

  void _subscribeToAnalysis() {
    _sub?.cancel();
    _sub = widget.analysisStream?.listen((frame) {
      if (mounted) {
        setState(() => _currentFrame = frame);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _fpsWatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presetId = widget.preset?.id ?? 'wmp_retro';
    final shadersAsync = ref.watch(webShaderProvider);

    // Fullscreen mode: no decorations, just the visualizer
    if (widget.isFullscreen) {
      return GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          height: widget.height,
          color: const Color(0xFF0A0A12),
          child: Stack(
            children: [
              // Visualizer - GPU or CPU
              shadersAsync.when(
                data: (shaders) {
                  final shader = shaders[presetId];
                  if (shader != null) {
                    return CustomPaint(
                      painter: GpuVisualizerPainter(
                        shader: shader,
                        frame: _currentFrame,
                        time: _time,
                        presetId: presetId,
                      ),
                      size: Size.infinite,
                      isComplex: true,
                      willChange: true,
                      child: Container(),
                    );
                  }
                  // Fallback to CPU painter
                  return CustomPaint(
                    painter: _getCpuPainter(presetId),
                    size: Size.infinite,
                  );
                },
                loading: () => _buildLoadingView(),
                error: (_, __) => CustomPaint(
                  painter: _getCpuPainter(presetId),
                  size: Size.infinite,
                ),
              ),

              // Preset label with GPU/CPU indicator
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shadersAsync.maybeWhen(
                          data: (shaders) => shaders[presetId] != null
                              ? Icons.memory
                              : Icons.computer,
                          orElse: () => Icons.computer,
                        ),
                        size: 10,
                        color: SlowverbColors.neonCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${shadersAsync.maybeWhen(data: (shaders) => shaders[presetId] != null ? 'GPU' : 'CPU', loading: () => '...', orElse: () => 'CPU')} · ${widget.preset?.name.toUpperCase() ?? 'WMP RETRO'}',
                        style: const TextStyle(
                          color: SlowverbColors.neonCyan,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Card mode: with decorations
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SlowverbColors.primaryPurple.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: SlowverbColors.neonCyan.withValues(alpha: 0.1),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Visualizer - GPU or CPU
              shadersAsync.when(
                data: (shaders) {
                  final shader = shaders[presetId];
                  if (shader != null) {
                    return CustomPaint(
                      painter: GpuVisualizerPainter(
                        shader: shader,
                        frame: _currentFrame,
                        time: _time,
                        presetId: presetId,
                      ),
                      size: Size.infinite,
                      isComplex: true,
                      willChange: true,
                      child: Container(),
                    );
                  }
                  // Fallback to CPU painter
                  return CustomPaint(
                    painter: _getCpuPainter(presetId),
                    size: Size.infinite,
                  );
                },
                loading: () => _buildLoadingView(),
                error: (_, __) => CustomPaint(
                  painter: _getCpuPainter(presetId),
                  size: Size.infinite,
                ),
              ),

              // Preset label with GPU/CPU indicator
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shadersAsync.maybeWhen(
                          data: (shaders) => shaders[presetId] != null
                              ? Icons.memory
                              : Icons.computer,
                          orElse: () => Icons.computer,
                        ),
                        size: 10,
                        color: SlowverbColors.neonCyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${shadersAsync.maybeWhen(data: (shaders) => shaders[presetId] != null ? 'GPU' : 'CPU', loading: () => '...', orElse: () => 'CPU')} · ${widget.preset?.name.toUpperCase() ?? 'WMP RETRO'}',
                        style: const TextStyle(
                          color: SlowverbColors.neonCyan,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFF0A0A12),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(SlowverbColors.neonCyan),
            ),
            SizedBox(height: 8),
            Text(
              'Loading GPU shaders...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  CustomPainter _getCpuPainter(String presetId) {
    switch (presetId) {
      case 'starfield_warp':
        return _StarfieldPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'pipes_vaporwave':
        return _PipesPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'maze_neon':
      case 'maze_repeat':
        return _MazePainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'mystify':
        return _MystifyPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'dvd_bounce':
        return _DvdBouncePainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'fractal_dream':
        return _FractalDreamPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      case 'rainy_window':
        return _RainyWindowPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
      default:
        return _WmpRetroPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
    }
  }
}

/// GPU-accelerated painter using FragmentShader
