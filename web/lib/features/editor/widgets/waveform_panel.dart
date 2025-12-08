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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/providers/waveform_provider.dart';

/// Waveform visualization panel with playhead
class WaveformPanel extends ConsumerStatefulWidget {
  final double playbackPosition; // 0.0 to 1.0
  final ValueChanged<double> onSeek;

  const WaveformPanel({
    super.key,
    required this.playbackPosition,
    required this.onSeek,
  });

  @override
  ConsumerState<WaveformPanel> createState() => _WaveformPanelState();
}

class _WaveformPanelState extends ConsumerState<WaveformPanel> {
  bool _isHovering = false;
  double? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    final waveformState = ref.watch(waveformProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: SlowverbTokens.spacingMd,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1B2F),
            Color(0xFF2A2343),
          ],
        ),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        border: Border.all(
          color: SlowverbColors.accentCyan.withOpacity(0.25),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusLg),
        child: waveformState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: SlowverbColors.accentCyan,
                ),
              )
            : waveformState.error != null
            ? Center(
                child: Text(
                  waveformState.error!,
                  style: const TextStyle(color: SlowverbColors.error),
                ),
              )
            : MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() {
                  _isHovering = false;
                  _hoverPosition = null;
                }),
                onHover: (event) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition = box.globalToLocal(event.position);
                  setState(() {
                    _hoverPosition = (localPosition.dx / box.size.width).clamp(
                      0.0,
                      1.0,
                    );
                  });
                },
                child: GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(
                      details.globalPosition,
                    );
                    final position = (localPosition.dx / box.size.width).clamp(
                      0.0,
                      1.0,
                    );
                    widget.onSeek(position);
                  },
                  child: CustomPaint(
                    painter: WaveformPainter(
                      playbackPosition: widget.playbackPosition,
                      hoverPosition: _isHovering ? _hoverPosition : null,
                      waveformData: waveformState.waveform,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final double playbackPosition;
  final double? hoverPosition;
  final Float32List? waveformData;

  WaveformPainter({
    required this.playbackPosition,
    this.hoverPosition,
    this.waveformData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use real waveform data if available, otherwise generate mock data
    final data = waveformData != null && waveformData!.isNotEmpty
        ? waveformData!
        : _generateMockWaveform(200);

    final paintPlayed = Paint()
      ..color = SlowverbColors.waveformActive
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintUnplayed = Paint()
      ..color = SlowverbColors.waveformInactive
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final playheadPaint = Paint()
      ..color = SlowverbColors.playhead
      ..strokeWidth = 2.0;

    final hoverPaint = Paint()
      ..color = SlowverbColors.textSecondary.withOpacity(0.5)
      ..strokeWidth = 1.0;

    // Draw waveform
    final barWidth = size.width / data.length;
    final centerY = size.height / 2;

    for (var i = 0; i < data.length; i++) {
      final x = i * barWidth;
      final barHeight = data[i].abs() * size.height * 0.4;

      final paint = (i / data.length) <= playbackPosition
          ? paintPlayed
          : paintUnplayed;

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }

    // Draw playhead
    final playheadX = size.width * playbackPosition;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );

    // Draw hover indicator
    if (hoverPosition != null) {
      final hoverX = size.width * hoverPosition!;
      canvas.drawLine(
        Offset(hoverX, 0),
        Offset(hoverX, size.height),
        hoverPaint,
      );
    }
  }

  List<double> _generateMockWaveform(int sampleCount) {
    // Generate procedural waveform data
    final data = <double>[];
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleCount;
      final amplitude = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2); // Peak in middle
      final noise = (i % 7) / 7 * 0.2; // Add variation
      data.add((amplitude + noise).clamp(0.1, 1.0));
    }
    return data;
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.playbackPosition != playbackPosition ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.waveformData != waveformData;
  }
}
