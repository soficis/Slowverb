import 'dart:async';
import 'dart:math' show sin, cos, pi, max, min, sqrt;

import 'package:flutter/material.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';

/// Web-optimized visualizer panel with nostalgic Windows Media Player-style bars.
/// Uses CustomPainter for smooth 60fps rendering via CanvasKit.
class VisualizerPanel extends StatefulWidget {
  final Stream<AudioAnalysisFrame>? analysisStream;
  final VisualizerPreset? preset;
  final double height;
  final bool isPlaying;

  const VisualizerPanel({
    super.key,
    this.analysisStream,
    this.preset,
    this.height = 120,
    this.isPlaying = false,
  });

  @override
  State<VisualizerPanel> createState() => _VisualizerPanelState();
}

class _VisualizerPanelState extends State<VisualizerPanel>
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);

    if (widget.isPlaying) _controller.repeat();
    _subscribeToAnalysis();
    _fpsWatch.start();
  }

  @override
  void didUpdateWidget(covariant VisualizerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisStream != oldWidget.analysisStream) {
      _subscribeToAnalysis();
    }
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _tick() {
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

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SlowverbColors.primaryPurple.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: SlowverbColors.neonCyan.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Visualizer
            CustomPaint(
              painter: _getVisualizerPainter(presetId),
              size: Size.infinite,
            ),

            // Preset label
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.graphic_eq,
                      size: 10,
                      color: SlowverbColors.neonCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.preset?.name.toUpperCase() ?? 'WMP RETRO',
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

  CustomPainter _getVisualizerPainter(String presetId) {
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
        return _MazePainter(
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
      default:
        return _WmpRetroPainter(
          frame: _currentFrame,
          time: _time,
          isPlaying: widget.isPlaying,
        );
    }
  }
}

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
