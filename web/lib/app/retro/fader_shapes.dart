import 'package:flutter/material.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

/// Mixing-desk fader cap: a small bevelled block with a centre line.
class FaderThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  const FaderThumbShape({this.width = 14, this.height = 24});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    final enabled = enableAnimation.value > 0.5;

    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: enabled
              ? const [Color(0xFFE4E3EC), Color(0xFF8C8B99)]
              : const [Color(0xFF6A6976), Color(0xFF45444F)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black,
    );
    // Centre index line, lit while dragging.
    final lit = activationAnimation.value;
    canvas.drawLine(
      Offset(rect.left + 2, center.dy),
      Offset(rect.right - 2, center.dy),
      Paint()
        ..strokeWidth = 2
        ..color = Color.lerp(
          const Color(0xFF2A2A33),
          SlowverbTokens.vfdCyan,
          lit,
        )!,
    );
  }
}

/// Recessed groove track; the active part glows VFD cyan.
class GrooveTrackShape extends RoundedRectSliderTrackShape {
  const GrooveTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final groove = RRect.fromRectAndRadius(
      rect.inflate(1),
      const Radius.circular(2),
    );
    canvas.drawRRect(groove, Paint()..color = SlowverbTokens.groove);
    canvas.drawRRect(
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF3A3A48),
    );
    final active = Rect.fromLTRB(
      rect.left,
      rect.top,
      thumbCenter.dx.clamp(rect.left, rect.right),
      rect.bottom,
    );
    final color = isEnabled
        ? (sliderTheme.activeTrackColor ?? SlowverbTokens.vfdCyan)
        : SlowverbTokens.textHint.withValues(alpha: 0.4);
    if (isEnabled) {
      canvas.drawRect(
        active,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawRect(active, Paint()..color = color);
  }
}
