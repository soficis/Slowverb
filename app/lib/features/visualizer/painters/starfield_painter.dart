import 'dart:math';

import 'package:flutter/material.dart';
import 'package:slowverb/domain/entities/visualizer_preset.dart';

class StarfieldPainter extends CustomPainter {
  final AudioAnalysisFrame frame;
  final Color starColor;

  // Cache simulated stars to avoid jitter, but we need state.
  // Since CustomPainter is stateless, we use the frame data to deterministically
  // drive the "Z" position or just simulate flow.
  // Ideally, logic should be in controller, but for visual-only effects:

  StarfieldPainter({required this.frame, required this.starColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.magnitudes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = starColor;

    // Use the frame data to create a deterministic "random" star field
    // capable of reacting to beat.

    final level = frame.level;
    final speedMultiplier = 1.0 + (level * 2.0); // Beat speeds up stars

    // We'll generate stars on the fly but use a consistent seed + time offset concept?
    // Actually, simply drawing particles based on time would be better, but we don't pass time here.
    // We'll use the magnitudes sequence as a pseudo-random seed source for positions.

    final random = Random(42); // specific seed for consistent layout base

    for (int i = 0; i < 100; i++) {
      // Deterministic randomness
      final angle = random.nextDouble() * 2 * pi * speedMultiplier;
      var dist = random.nextDouble() * size.width;

      // Animate distance based on bass/level "pulse"
      // This is a cheap simulation: effectively "zooming" slightly on beat
      dist =
          dist * (0.8 + (frame.magnitudes[i % frame.magnitudes.length] * 0.4));

      // Perspective projection simulation
      final x = center.dx + cos(angle) * dist;
      final y = center.dy + sin(angle) * dist;

      // Size based on proximity/level
      final radius = (dist / size.width) * 3.0 * (1.0 + level);

      // Opacity based on distance (fade out at edges)
      final opacity = (1.0 - (dist / size.width)).clamp(0.0, 1.0);
      paint.color = starColor.withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Draw "warp lines" if high intensity
      if (level > 0.6) {
        final tailX = center.dx + cos(angle) * (dist * 0.9);
        final tailY = center.dy + sin(angle) * (dist * 0.9);
        paint.strokeWidth = radius;
        canvas.drawLine(Offset(x, y), Offset(tailX, tailY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
