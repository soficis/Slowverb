part of 'visualizer_panel.dart';

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
    const skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1a1a2e), Color(0xFF2d3561)],
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
    const segments = 8;

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
    const barCount = 16;
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
