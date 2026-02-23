part of 'visualizer_panel.dart';

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
