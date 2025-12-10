import 'package:flutter/material.dart';
import 'package:slowverb/domain/entities/visualizer_preset.dart';

class WmpRetroPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final Color primaryColor;
  final Color secondaryColor;

  WmpRetroPainter({
    required this.frame,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.magnitudes.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final width = size.width;
    final bands = frame.magnitudes;
    final count = bands.length;
    final step = width / (count - 1);

    // Draw the "Wave" (Oscilloscope style)
    final path = Path();
    for (var i = 0; i < count; i++) {
      final x = i * step;
      // Mirror effect for retro coolness
      final amp = bands[i] * size.height * 0.4;
      // Alternate up/down for a jagged "digital" feel like Winamp/WMP
      final y = centerY + (i.isEven ? -amp : amp);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Quadratic bezier for smoother look
        final prevX = (i - 1) * step;
        final prevAmp = bands[i - 1] * size.height * 0.4;
        final prevY = centerY + ((i - 1).isEven ? -prevAmp : prevAmp);

        final cx = (prevX + x) / 2;
        final cy = (prevY + y) / 2;

        path.quadraticBezierTo(prevX, prevY, cx, cy);
      }
    }

    // Glow effect
    paint.color = primaryColor.withOpacity(0.3);
    paint.strokeWidth = 6.0;
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawPath(path, paint);

    // Main line
    paint.maskFilter = null;
    paint.color = primaryColor;
    paint.strokeWidth = 2.0;
    canvas.drawPath(path, paint);

    // Draw "Bars" at bottom (Spectrum Analyzer)
    final barPaint = Paint()..style = PaintingStyle.fill;
    final barWidth = (width / count) * 0.6;

    for (var i = 0; i < count; i++) {
      final value = bands[i];
      final barHeight = value * size.height * 0.3;

      final x = i * (width / count) + ((width / count) - barWidth) / 2;
      final y = size.height;

      barPaint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          secondaryColor.withOpacity(0.8),
          primaryColor.withOpacity(0.8),
          Colors.white.withOpacity(0.5),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(x, y - barHeight, barWidth, barHeight));

      canvas.drawRect(
        Rect.fromLTWH(x, y - barHeight, barWidth, barHeight),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WmpRetroPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
