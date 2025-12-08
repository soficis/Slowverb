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
import 'package:slowverb_web/app/colors.dart';

/// Transport controls for audio playback
class TransportBar extends StatelessWidget {
  final bool isPlaying;
  final Duration currentTime;
  final Duration totalTime;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPreview;
  final ValueChanged<Duration> onSeek;

  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.totalTime,
    required this.onPlayPause,
    required this.onStop,
    required this.onPreview,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = totalTime.inMilliseconds;
    final safeTotalMs = totalMs <= 0 ? 1 : totalMs;
    final progress =
        (totalMs <= 0) ? 0.0 : currentTime.inMilliseconds / safeTotalMs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Time + seek slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0),
                  onChanged: (value) => onSeek(
                    Duration(milliseconds: (value * safeTotalMs).toInt()),
                  ),
                  activeColor: SlowverbColors.primaryPurple,
                  inactiveColor: SlowverbColors.textSecondary.withOpacity(0.3),
                ),
                Text(
                  '${_formatDuration(currentTime)} / ${_formatDuration(totalTime)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),

          // Transport controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stop
              IconButton(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop',
                color: SlowverbColors.textPrimary,
              ),

              const SizedBox(width: 8),

              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  gradient: SlowverbColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SlowverbColors.primaryPurple.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: onPlayPause,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 32,
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Preview button
          ElevatedButton.icon(
            onPressed: onPreview,
            style: ElevatedButton.styleFrom(
              backgroundColor: SlowverbColors.surfaceVariant,
              foregroundColor: SlowverbColors.textPrimary,
            ),
            icon: const Icon(Icons.headphones, size: 20),
            label: const Text('PREVIEW FULL'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
