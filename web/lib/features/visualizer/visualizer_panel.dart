import 'dart:async';
import 'dart:math' show sin, cos, pi, max, min, sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

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
class GpuVisualizerPainter extends CustomPainter {
  final ui.FragmentProgram shader;
  final AudioAnalysisFrame frame;
  final double time;
  final String presetId;

  GpuVisualizerPainter({
    required this.shader,
    required this.frame,
    required this.time,
    required this.presetId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fragmentShader = shader.fragmentShader();

    // Set uniforms based on preset type
    if (presetId == 'fractal_dreams_3d') {
      // Fractal Dreams 3D shader uniforms:
      // uniform float uTime;
      // uniform vec2 uResolution;
      // uniform float uWarp;
      // uniform float uChroma;
      // uniform float uVig;
      // uniform float uGrain;
      fragmentShader.setFloat(0, time);
      fragmentShader.setFloat(1, size.width);
      fragmentShader.setFloat(2, size.height);

      // Effect parameters with slow modulation
      final breath = 0.5 + 0.5 * sin(time * 0.11);
      fragmentShader.setFloat(3, 0.4 + 0.2 * breath); // uWarp
      fragmentShader.setFloat(4, 0.4 + 0.3 * breath); // uChroma
      fragmentShader.setFloat(5, 0.5); // uVig
      fragmentShader.setFloat(6, 0.2); // uGrain
    } else {
      // Standard shader uniforms:
      // uniform float uTime;
      // uniform float uResolutionX;
      // uniform float uResolutionY;
      // uniform float uLevel;
      fragmentShader.setFloat(0, time);
      fragmentShader.setFloat(1, size.width);
      fragmentShader.setFloat(2, size.height);
      fragmentShader.setFloat(3, _calculateLevel());
    }

    final paint = Paint()..shader = fragmentShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  double _calculateLevel() {
    // Combine RMS with bass for a punchy audio-reactive response
    final level = (frame.rms * 0.6 + frame.bass * 0.4).clamp(0.0, 1.0);
    return level;
  }

  @override
  bool shouldRepaint(covariant GpuVisualizerPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.frame.rms != frame.rms;
  }
}

// =============================================================================
// CPU Fallback Painters (unchanged from original implementation)
// =============================================================================

/// Windows Media Player-style frequency bars
class _WmpRetroPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _WmpRetroPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Number of bars
    const barCount = 32;
    final barWidth = size.width / barCount - 2;

    for (var i = 0; i < barCount; i++) {
      // Calculate bar height from spectrum or fake animation
      double normalizedHeight;
      if (isPlaying && frame.spectrum.isNotEmpty) {
        final idx = (i * frame.spectrum.length / barCount).floor().clamp(
          0,
          frame.spectrum.length - 1,
        );
        normalizedHeight = frame.spectrum[idx];
      } else if (isPlaying) {
        // Fake animation when no spectrum
        final phase = i * 0.2 + time * 3;
        normalizedHeight = 0.3 + 0.5 * (sin(phase) + 1) / 2;
      } else {
        // Idle state - minimal bars
        normalizedHeight = 0.05 + (i % 3) * 0.02;
      }

      final barHeight = normalizedHeight * (size.height * 0.85);
      final x = i * (barWidth + 2);
      final y = size.height - barHeight;

      // Gradient from pink to cyan
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [SlowverbColors.hotPink, SlowverbColors.neonCyan],
      );

      paint.shader = gradient.createShader(
        Rect.fromLTWH(x, y, barWidth, barHeight),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );

      // Peak indicator
      if (normalizedHeight > 0.7) {
        paint.shader = null;
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(x, y - 2, barWidth, 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WmpRetroPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.frame.rms != frame.rms ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// Simple starfield visualization
class _StarfieldPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _StarfieldPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Speed based on audio level
    final speed = isPlaying ? 1.0 + frame.rms * 2 : 0.3;

    // Draw stars
    for (var i = 0; i < 80; i++) {
      // Pseudo-random but deterministic positions
      final seed = i * 7 + 13;
      final angle = (seed % 360) * pi / 180;
      final baseDistance = (seed * 17 % 100) / 100.0;

      // Stars move outward based on time
      final distance = ((baseDistance + time * speed * 0.1) % 1.0);
      final x = centerX + cos(angle) * distance * max(size.width, size.height);
      final y = centerY + sin(angle) * distance * max(size.width, size.height);

      // Size and brightness increase as stars get closer
      final starSize = 1.0 + distance * 3;
      final alpha = (distance * 255).round().clamp(30, 255);

      paint.color = Color.fromARGB(alpha, 255, 255, 255);
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  double cos(double radians) => sin(radians + pi / 2);

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}

/// 3D Pipes screensaver homage - neon pipes growing and turning
class _PipesPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _PipesPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Pipe thickness based on bass
    final thickness = isPlaying ? 4 + frame.bass * 8 : 4.0;
    paint.strokeWidth = thickness;

    // Draw multiple pipe segments
    const segmentCount = 12;
    final path = Path();

    var x = size.width * 0.1;
    var y = size.height * 0.5;
    path.moveTo(x, y);

    for (var i = 0; i < segmentCount; i++) {
      final seed = (i * 7 + (time * 2).floor()) % 4;
      final segmentLength = size.width / segmentCount;

      switch (seed) {
        case 0:
          x += segmentLength;
        case 1:
          y -= segmentLength * 0.5;
        case 2:
          y += segmentLength * 0.5;
        default:
          x += segmentLength * 0.7;
          y += (i % 2 == 0 ? -1 : 1) * segmentLength * 0.3;
      }

      y = y.clamp(10, size.height - 10);
      x = min(x, size.width - 10);
      path.lineTo(x, y);
    }

    final hueShift = isPlaying ? frame.treble * 60 : 0;
    final gradient = LinearGradient(
      colors: [
        HSLColor.fromAHSL(1, (300 + hueShift) % 360, 0.8, 0.6).toColor(),
        HSLColor.fromAHSL(1, (180 + hueShift) % 360, 0.9, 0.5).toColor(),
      ],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    canvas.drawPath(path, paint);

    paint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    paint.strokeWidth = thickness / 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PipesPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.frame.bass != frame.bass ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// Neon maze with camera navigation effect
class _MazePainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _MazePainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final speed = isPlaying ? 0.5 + frame.bass * 1.5 : 0.2;
    final offset = (time * speed * 50) % 50;

    const cellSize = 50.0;
    final cols = (size.width / cellSize).ceil() + 1;
    final rows = (size.height / cellSize).ceil() + 1;

    final flicker = isPlaying ? 0.7 + frame.treble * 0.3 : 0.8;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * cellSize - offset;
        final y = row * cellSize - offset * 0.5;

        final seed = (col * 7 + row * 13) % 5;
        final hasRight = seed < 3;
        final hasBottom = seed < 2 || seed == 4;

        final distanceFromCenter = sqrt(
          _pow(x - size.width / 2) + _pow(y - size.height / 2),
        );
        final alpha = ((1 - distanceFromCenter / size.width) * 255 * flicker)
            .round()
            .clamp(30, 255);

        paint.color = Color.fromARGB(alpha, 0, 255, 200);

        if (hasRight && x + cellSize < size.width) {
          canvas.drawLine(
            Offset(x + cellSize, y),
            Offset(x + cellSize, y + cellSize),
            paint,
          );
        }
        if (hasBottom && y + cellSize < size.height) {
          canvas.drawLine(
            Offset(x, y + cellSize),
            Offset(x + cellSize, y + cellSize),
            paint,
          );
        }
      }
    }
  }

  double _pow(double a) => a * a;

  @override
  bool shouldRepaint(covariant _MazePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}

/// Fractal Dream - simplified Mandelbrot-inspired zoom
class _FractalDreamPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _FractalDreamPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final zoomSpeed = isPlaying ? 0.3 + frame.bass * 0.7 : 0.1;
    final zoom = 1.5 + sin(time * zoomSpeed) * 0.5;

    final offsetX = isPlaying ? frame.mid * 0.2 : 0.0;
    final offsetY = isPlaying ? frame.mid * 0.1 : 0.0;

    final hueBase = isPlaying ? (time * 20 + frame.treble * 60) % 360 : 280.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = max(size.width, size.height) * 0.6;

    for (var i = 20; i > 0; i--) {
      final radius = (maxRadius / 20) * i * zoom;
      final hue = (hueBase + i * 15) % 360;
      final saturation = 0.6 + (i / 40);
      final lightness = 0.3 + (i / 60);

      paint.color = HSLColor.fromAHSL(
        0.8,
        hue,
        saturation.clamp(0.0, 1.0),
        lightness.clamp(0.0, 0.6),
      ).toColor();

      final ringOffsetX = sin(time + i * 0.3) * 10 + offsetX * 20;
      final ringOffsetY = cos(time + i * 0.3) * 10 + offsetY * 20;

      canvas.drawCircle(
        Offset(centerX + ringOffsetX, centerY + ringOffsetY),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FractalDreamPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.frame.bass != frame.bass ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// Mystify - classic polygon morphing screensaver screensaver
class _MystifyPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _MystifyPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;

    // Use bass to pump the speed/intensity
    final boost = isPlaying ? 1.0 + frame.bass * 2.0 : 0.5;
    final t = time * 0.4 * boost;

    // Draw 4 trailing polygons
    for (int trail = 0; trail < 4; trail++) {
      final trailOffset = trail * 0.05;
      final trailAlpha = (1.0 - trail * 0.2).clamp(0.1, 1.0);

      // Color cycles
      final hue =
          (time * 40 + trail * 20 + (isPlaying ? frame.mid * 100 : 0)) % 360;
      paint.color = HSLColor.fromAHSL(trailAlpha, hue, 0.8, 0.6).toColor();
      paint.strokeWidth = isPlaying ? 2.0 + frame.treble * 4 : 2.0;

      final path = Path();

      // A polygon with 4 vertices
      for (int v = 0; v < 4; v++) {
        // Unique speeds for each vertex's components
        final sx = (v + 1) * 0.73;
        final sy = (v + 2) * 0.61;

        final vx = _bounce(t - trailOffset, sx, width);
        final vy = _bounce(t - trailOffset + 100, sy, height);

        if (v == 0) {
          path.moveTo(vx, vy);
        } else {
          path.lineTo(vx, vy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  // Triangle wave function to simulate bouncing between 0 and max
  double _bounce(double t, double speed, double max) {
    final period = max * 2;
    // Normalized position in cycle [0, 2]
    double pos = (t * speed * 100) % period;
    // Fold back
    if (pos > max) {
      pos = period - pos;
    }
    return pos;
  }

  @override
  bool shouldRepaint(covariant _MystifyPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}

/// DVD Bounce - bouncing logo homage
class _DvdBouncePainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _DvdBouncePainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const logoWidth = 80.0;
    const logoHeight = 40.0;
    final maxX = size.width - logoWidth;
    final maxY = size.height - logoHeight;

    // Speed heavily influenced by BPM/Rhythm if possible, essentially bass
    final speed = isPlaying ? 100.0 + frame.bass * 200.0 : 60.0;
    final t = time * speed;

    // Position
    final x = _bounce(t, 1.0, maxX);
    final y = _bounce(t, 0.8, maxY);

    // Determine wall hits to change color
    // A hit happens when the triangle wave peaks or troughs.
    // Total bounces ~ t / maxX ... rough approximation for color change:
    final bounceCount = (t / maxX).floor() + (t / maxY).floor();

    // Color
    final hue = ((bounceCount * 60 + (isPlaying ? frame.mid * 30 : 0)) % 360)
        .toDouble();
    final color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor();

    // Draw "DVD" / "Slowverb" pill
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Glow effect
    if (isPlaying && frame.bass > 0.6) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      // Double draw for glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, logoWidth, logoHeight),
          const Radius.circular(20),
        ),
        paint,
      );
      paint.maskFilter = null;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, logoWidth, logoHeight),
        const Radius.circular(20),
      ),
      paint,
    );

    // Text
    textPainter.text = TextSpan(
      text: 'DVD',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        letterSpacing: 2,
        fontFamily: 'Courier',
        shadows: [
          Shadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: dataFromAmp(frame.bass).toDouble(),
          ),
        ],
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        x + (logoWidth - textPainter.width) / 2,
        y + (logoHeight - textPainter.height) / 2,
      ),
    );
  }

  double dataFromAmp(double amp) => amp * 10;

  double _bounce(double t, double speedFactor, double max) {
    if (max <= 0) return 0;
    final fullRange = max * 2;
    double val = (t * speedFactor) % fullRange;
    if (val > max) {
      val = fullRange - val;
    }
    return val;
  }

  @override
  bool shouldRepaint(covariant _DvdBouncePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}

/// Rainy Window - 90s PC box looking at a stormy day
class _RainyWindowPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final double time;
  final bool isPlaying;

  _RainyWindowPainter({
    required this.frame,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background - dark stormy sky
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF1a1a2e), const Color(0xFF2d3561)],
    );
    final skyPaint = Paint()
      ..shader = skyGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Lightning flash - triggered by bass
    if (isPlaying && frame.bass > 0.65) {
      final flashIntensity = (frame.bass - 0.65) / 0.35;
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashIntensity * 0.3);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);

      // Lightning bolt
      _drawLightning(canvas, size, flashIntensity);
    }

    // Window frame
    _drawWindow(canvas, size);

    // Rain - intensity based on mid/treble
    _drawRain(canvas, size);

    // Warm room glow from desk lamp
    _drawRoomAmbience(canvas, size);

    // Desk surface
    _drawDesk(canvas, size);

    // PC box
    _drawPCBox(canvas, size);

    // CRT Monitor with music-reactive screen
    _drawCRTMonitor(canvas, size);

    // Coffee mug
    _drawCoffeeMug(canvas, size);

    // Desk lamp
    _drawDeskLamp(canvas, size);
  }

  void _drawLightning(Canvas canvas, Size size, double intensity) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7 + intensity * 0.3)
      ..strokeWidth = 2 + intensity * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Lightning bolt path - jagged line from top to middle
    final startX = size.width * 0.6 + (time * 100 % 40) - 20;
    final path = Path()..moveTo(startX, 0);

    var currentX = startX;
    var currentY = 0.0;
    final segments = 8;

    for (var i = 0; i < segments; i++) {
      final newY = currentY + size.height / segments / 2;
      final jitter = ((i * 17 + time * 50) % 30) - 15;
      currentX += jitter;
      path.lineTo(currentX, newY);
      currentY = newY;
    }

    canvas.drawPath(path, paint);

    // Glow effect
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    paint.strokeWidth = 4;
    canvas.drawPath(path, paint);
  }

  void _drawWindow(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = const Color(0xFF4a4a4a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    // Outer window frame
    final frameRect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.7,
    );
    canvas.drawRect(frameRect, framePaint);

    // Muntins (window dividers) - create 6 panes
    framePaint.strokeWidth = 4;

    // Vertical dividers
    final dividerX1 = size.width * 0.1 + (size.width * 0.8) / 3;
    final dividerX2 = size.width * 0.1 + (size.width * 0.8) * 2 / 3;
    canvas.drawLine(
      Offset(dividerX1, size.height * 0.1),
      Offset(dividerX1, size.height * 0.8),
      framePaint,
    );
    canvas.drawLine(
      Offset(dividerX2, size.height * 0.1),
      Offset(dividerX2, size.height * 0.8),
      framePaint,
    );

    // Horizontal divider
    final dividerY = size.height * 0.1 + (size.height * 0.7) / 2;
    canvas.drawLine(
      Offset(size.width * 0.1, dividerY),
      Offset(size.width * 0.9, dividerY),
      framePaint,
    );
  }

  void _drawRain(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Rain intensity based on audio
    final rainSpeed = isPlaying ? 1.0 + frame.mid * 2.0 : 0.5;
    final rainCount = isPlaying ? 80 + (frame.treble * 40).round() : 50;

    for (var i = 0; i < rainCount; i++) {
      // Pseudo-random but deterministic positions
      final seed = i * 11 + 7;
      final x = (seed * 19 % size.width.toInt()).toDouble();
      final baseY = (seed * 23 % size.height.toInt()).toDouble();

      // Animated fall
      final y = (baseY + time * rainSpeed * 200) % size.height;
      final rainLength = 15 + (seed % 10);

      // Rain color - blue-gray with transparency
      final alpha = (100 + (seed % 100)).clamp(80, 180);
      rainPaint.color = Color.fromARGB(alpha, 120, 140, 180);

      // Draw raindrop
      canvas.drawLine(Offset(x, y), Offset(x + 2, y + rainLength), rainPaint);
    }
  }

  void _drawPCBox(Canvas canvas, Size size) {
    final pcWidth = size.width * 0.15;
    final pcHeight = size.height * 0.35;
    final pcX = size.width * 0.05;
    final pcY = size.height - pcHeight - size.height * 0.05;

    // PC case - beige color
    final pcPaint = Paint()
      ..color =
          const Color(0xFFe8d5b7) // Classic beige
      ..style = PaintingStyle.fill;

    final pcRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pcX, pcY, pcWidth, pcHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(pcRect, pcPaint);

    // Panel details - darker shade for depth
    final panelPaint = Paint()
      ..color = const Color(0xFFd4c4a8)
      ..style = PaintingStyle.fill;

    // Drive bays
    final bayHeight = pcHeight * 0.08;
    final bayY1 = pcY + pcHeight * 0.15;
    final bayY2 = pcY + pcHeight * 0.25;

    canvas.drawRect(
      Rect.fromLTWH(pcX + pcWidth * 0.1, bayY1, pcWidth * 0.8, bayHeight),
      panelPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(pcX + pcWidth * 0.1, bayY2, pcWidth * 0.8, bayHeight),
      panelPaint,
    );

    // Power button
    final buttonPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.fill;

    final buttonX = pcX + pcWidth * 0.5;
    final buttonY = pcY + pcHeight * 0.7;
    canvas.drawCircle(Offset(buttonX, buttonY), pcWidth * 0.08, buttonPaint);

    // LED indicator - glows green, pulses with RMS
    final ledIntensity = isPlaying ? 0.5 + frame.rms * 0.5 : 0.3;
    final ledPaint = Paint()
      ..color = const Color(0xFF00ff00).withValues(alpha: ledIntensity)
      ..style = PaintingStyle.fill;

    final ledX = pcX + pcWidth * 0.5;
    final ledY = pcY + pcHeight * 0.85;
    canvas.drawCircle(Offset(ledX, ledY), pcWidth * 0.04, ledPaint);

    // LED glow
    if (isPlaying) {
      ledPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(ledX, ledY), pcWidth * 0.06, ledPaint);
    }

    // Edge highlights for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(pcX, pcY),
      Offset(pcX + pcWidth, pcY),
      highlightPaint,
    );
    canvas.drawLine(
      Offset(pcX, pcY),
      Offset(pcX, pcY + pcHeight),
      highlightPaint,
    );
  }

  void _drawRoomAmbience(Canvas canvas, Size size) {
    // Warm amber glow from desk lamp in bottom right
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFffb347).withValues(alpha: 0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.75),
              radius: size.width * 0.35,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      size.width * 0.35,
      glowPaint,
    );
  }

  void _drawDesk(Canvas canvas, Size size) {
    // Wooden desk surface - warm brown
    final deskPaint = Paint()
      ..color = const Color(0xFF8B7355)
      ..style = PaintingStyle.fill;

    final deskRect = Rect.fromLTWH(
      0,
      size.height * 0.78,
      size.width,
      size.height * 0.22,
    );
    canvas.drawRect(deskRect, deskPaint);

    // Wood grain texture (subtle lines)
    final grainPaint = Paint()
      ..color = const Color(0xFF6d5d47).withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 5; i++) {
      final y = size.height * 0.78 + (i * 15.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grainPaint);
    }

    // Desk edge highlight
    final edgePaint = Paint()
      ..color = const Color(0xFFa08968)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.78),
      Offset(size.width, size.height * 0.78),
      edgePaint,
    );
  }

  void _drawCRTMonitor(Canvas canvas, Size size) {
    final monitorX = size.width * 0.25;
    final monitorY = size.height * 0.55;
    final monitorWidth = size.width * 0.25;
    final monitorHeight = size.height * 0.23;

    // Monitor casing - beige/gray plastic
    final casingPaint = Paint()
      ..color = const Color(0xFFd4d0c8)
      ..style = PaintingStyle.fill;

    final casingRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(monitorX, monitorY, monitorWidth, monitorHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(casingRect, casingPaint);

    // Screen bezel - darker
    final bezelPaint = Paint()
      ..color = const Color(0xFF3a3a3a)
      ..style = PaintingStyle.fill;

    final bezelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        monitorX + monitorWidth * 0.08,
        monitorY + monitorHeight * 0.06,
        monitorWidth * 0.84,
        monitorHeight * 0.7,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(bezelRect, bezelPaint);

    // CRT screen - slightly curved, dark when off, glowing when playing
    final screenX = monitorX + monitorWidth * 0.1;
    final screenY = monitorY + monitorHeight * 0.08;
    final screenWidth = monitorWidth * 0.8;
    final screenHeight = monitorHeight * 0.66;

    // Screen glow - reacts to music
    if (isPlaying) {
      final screenGlowIntensity = 0.3 + frame.rms * 0.4;
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(
                  0xFF00ff88,
                ).withValues(alpha: screenGlowIntensity * 0.4),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(
                  screenX + screenWidth / 2,
                  screenY + screenHeight / 2,
                ),
                radius: screenWidth * 0.7,
              ),
            );

      canvas.drawRect(
        Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
        glowPaint,
      );
    }

    // Screen content - music visualizer bars
    final screenPaint = Paint()
      ..color = isPlaying ? const Color(0xFF003322) : const Color(0xFF1a1a1a)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
        const Radius.circular(2),
      ),
      screenPaint,
    );

    // Music-reactive content on screen
    if (isPlaying) {
      _drawCRTContent(canvas, screenX, screenY, screenWidth, screenHeight);
    }

    // CRT scanlines
    final scanlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < screenHeight ~/ 2; i++) {
      canvas.drawLine(
        Offset(screenX, screenY + i * 2.0),
        Offset(screenX + screenWidth, screenY + i * 2.0),
        scanlinePaint,
      );
    }

    // Screen reflection
    final reflectionPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.1),
            ],
          ).createShader(
            Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
          );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight),
        const Radius.circular(2),
      ),
      reflectionPaint,
    );

    // Monitor brand logo (subtle)
    final logoPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(monitorX + monitorWidth / 2, monitorY + monitorHeight * 0.85),
      4,
      logoPaint,
    );

    // Power LED
    final powerLedPaint = Paint()
      ..color = isPlaying
          ? const Color(0xFF00ff00).withValues(alpha: 0.8)
          : const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(monitorX + monitorWidth * 0.2, monitorY + monitorHeight * 0.88),
      3,
      powerLedPaint,
    );

    if (isPlaying) {
      powerLedPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(
        Offset(monitorX + monitorWidth * 0.2, monitorY + monitorHeight * 0.88),
        5,
        powerLedPaint,
      );
    }
  }

  void _drawCRTContent(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
  ) {
    // Simple frequency bars on the CRT screen
    final barCount = 16;
    final barWidth = width / barCount - 2;
    final barPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {
      double barHeight;
      if (frame.spectrum.isNotEmpty) {
        final idx = (i * frame.spectrum.length / barCount).floor().clamp(
          0,
          frame.spectrum.length - 1,
        );
        barHeight = frame.spectrum[idx] * height * 0.8;
      } else {
        // Fake animation
        final phase = i * 0.3 + time * 2;
        barHeight = (0.2 + 0.3 * (sin(phase) + 1) / 2) * height * 0.8;
      }

      final barX = x + i * (barWidth + 2) + 2;
      final barY = y + height - barHeight - 4;

      // Green phosphor glow
      barPaint.color = const Color(0xFF00ff88).withValues(alpha: 0.9);

      canvas.drawRect(Rect.fromLTWH(barX, barY, barWidth, barHeight), barPaint);

      // Phosphor glow effect
      barPaint.color = const Color(0xFF00ff88).withValues(alpha: 0.3);
      barPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRect(
        Rect.fromLTWH(barX - 1, barY - 1, barWidth + 2, barHeight + 2),
        barPaint,
      );
      barPaint.maskFilter = null;
    }
  }

  void _drawCoffeeMug(Canvas canvas, Size size) {
    final mugX = size.width * 0.65;
    final mugY = size.height * 0.83;
    final mugWidth = size.width * 0.06;
    final mugHeight = size.height * 0.08;

    // Mug body - ceramic white/cream
    final mugPaint = Paint()
      ..color = const Color(0xFFeee8d5)
      ..style = PaintingStyle.fill;

    final mugRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(mugX, mugY, mugWidth, mugHeight),
      const Radius.circular(3),
    );
    canvas.drawRRect(mugRect, mugPaint);

    // Coffee inside - dark brown
    final coffeePaint = Paint()
      ..color = const Color(0xFF3e2723)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(
        mugX + mugWidth * 0.1,
        mugY + mugHeight * 0.15,
        mugWidth * 0.8,
        mugHeight * 0.2,
      ),
      coffeePaint,
    );

    // Steam - rises with music intensity
    final steamIntensity = isPlaying ? 0.3 + frame.mid * 0.5 : 0.3;
    _drawSteam(canvas, mugX + mugWidth / 2, mugY, steamIntensity);

    // Mug handle
    final handlePaint = Paint()
      ..color = const Color(0xFFddd8c5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final handlePath = Path()
      ..moveTo(mugX + mugWidth, mugY + mugHeight * 0.3)
      ..quadraticBezierTo(
        mugX + mugWidth * 1.3,
        mugY + mugHeight * 0.5,
        mugX + mugWidth,
        mugY + mugHeight * 0.7,
      );

    canvas.drawPath(handlePath, handlePaint);

    // Mug shadow/depth
    final shadowPaint = Paint()
      ..color = const Color(0xFFc9c3b0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(mugX + mugWidth * 0.9, mugY),
      Offset(mugX + mugWidth * 0.9, mugY + mugHeight),
      shadowPaint,
    );
  }

  void _drawSteam(Canvas canvas, double x, double y, double intensity) {
    final steamPaint = Paint()
      ..color = Colors.white.withValues(alpha: intensity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final offset = i * 8.0;

      final path = Path()..moveTo(x + offset - 8, y);

      for (var j = 0; j < 5; j++) {
        final waveY = y - j * 8.0;
        final waveX = x + offset - 8 + sin(time * 3 + j * 0.5 + i) * 3;
        path.lineTo(waveX, waveY);
      }

      canvas.drawPath(path, steamPaint);
    }
  }

  void _drawDeskLamp(Canvas canvas, Size size) {
    final lampX = size.width * 0.85;
    final lampBaseY = size.height * 0.78;

    // Lamp base - round metal
    final basePaint = Paint()
      ..color = const Color(0xFF505050)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lampX, lampBaseY), 12, basePaint);

    // Lamp arm - articulated
    final armPaint = Paint()
      ..color = const Color(0xFF606060)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final armPath = Path()
      ..moveTo(lampX, lampBaseY)
      ..lineTo(lampX + 15, lampBaseY - 30)
      ..lineTo(lampX + 25, lampBaseY - 50);

    canvas.drawPath(armPath, armPaint);

    // Lamp shade - conical
    final shadePaint = Paint()
      ..color = const Color(0xFF4a4a4a)
      ..style = PaintingStyle.fill;

    final shadePath = Path()
      ..moveTo(lampX + 15, lampBaseY - 50)
      ..lineTo(lampX + 35, lampBaseY - 45)
      ..lineTo(lampX + 30, lampBaseY - 35)
      ..close();

    canvas.drawPath(shadePath, shadePaint);

    // Light glow - warm amber
    final lightIntensity = isPlaying ? 0.6 + frame.rms * 0.4 : 0.5;
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFffcc66).withValues(alpha: lightIntensity),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(lampX + 25, lampBaseY - 40),
              radius: 60,
            ),
          );

    canvas.drawCircle(Offset(lampX + 25, lampBaseY - 40), 60, glowPaint);

    // Bulb (subtle)
    final bulbPaint = Paint()
      ..color = const Color(0xFFffffcc).withValues(alpha: lightIntensity * 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lampX + 25, lampBaseY - 42), 6, bulbPaint);
  }

  @override
  bool shouldRepaint(covariant _RainyWindowPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.frame.bass != frame.bass ||
        oldDelegate.isPlaying != isPlaying;
  }
}
