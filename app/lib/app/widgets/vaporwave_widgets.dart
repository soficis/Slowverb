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
import 'package:flutter/material.dart';
import 'package:slowverb/app/colors.dart';

/// Scan line overlay widget for vaporwave aesthetic
class ScanLines extends StatelessWidget {
  const ScanLines({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              SlowverbColors.scanLineColor,
              Colors.transparent,
              SlowverbColors.scanLineColor,
              Colors.transparent,
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            tileMode: TileMode.repeated,
          ),
        ),
      ),
    );
  }
}

/// Grid pattern background for vaporwave aesthetic
class GridPattern extends StatelessWidget {
  const GridPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: Container());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SlowverbColors.gridColor.withValues(
        alpha: SlowverbColors.gridOpacity,
      )
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const gridSize = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glassmorphism container for vaporwave aesthetic
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: SlowverbColors.surface.withValues(alpha: 0.3),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: SlowverbColors.neonCyan.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SlowverbColors.neonCyan.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Neon button with glow effect
class NeonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color glowColor;
  final bool isPrimary;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.glowColor = SlowverbColors.neonCyan,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: glowColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: glowColor,
                side: BorderSide(color: glowColor, width: 2),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            ),
    );
  }
}
