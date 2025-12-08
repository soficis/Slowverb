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
import 'package:slowverb_web/app/slowverb_design_tokens.dart';

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
        totalMs <= 0 ? 0.0 : currentTime.inMilliseconds / safeTotalMs;

    return Container(
      padding: const EdgeInsets.all(SlowverbTokens.spacingMd),
      decoration: BoxDecoration(
        color: SlowverbColors.surfaceVariant,
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusMd),
        border: Border.all(
          color: SlowverbColors.accentPink.withOpacity(0.25),
        ),
        boxShadow: [SlowverbTokens.shadowCard],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final seekSection = _SeekSection(
            progress: progress,
            currentTime: currentTime,
            totalTime: totalTime,
            onSeek: (value) => onSeek(
              Duration(milliseconds: (value * safeTotalMs).toInt()),
            ),
          );
          final transportControls = _TransportControls(
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
            onStop: onStop,
          );
          final previewButton = _PreviewButton(onPreview: onPreview);

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                seekSection,
                const SizedBox(height: SlowverbTokens.spacingSm),
                Row(
                  children: [
                    transportControls,
                    const SizedBox(width: SlowverbTokens.spacingSm),
                    Expanded(child: previewButton),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: seekSection),
              const SizedBox(width: SlowverbTokens.spacingLg),
              transportControls,
              const Spacer(),
              previewButton,
            ],
          );
        },
      ),
    );
  }
}

class _SeekSection extends StatelessWidget {
  final double progress;
  final Duration currentTime;
  final Duration totalTime;
  final ValueChanged<double> onSeek;

  const _SeekSection({
    required this.progress,
    required this.currentTime,
    required this.totalTime,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0),
          onChanged: onSeek,
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
    );
  }
}

class _TransportControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  const _TransportControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChromeIconButton(
          icon: Icons.stop,
          tooltip: 'Stop',
          onPressed: onStop,
        ),
        const SizedBox(width: SlowverbTokens.spacingSm),
        DecoratedBox(
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
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final VoidCallback onPreview;

  const _PreviewButton({required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPreview,
      style: ElevatedButton.styleFrom(
        backgroundColor: SlowverbColors.surface,
        foregroundColor: SlowverbColors.textPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: SlowverbTokens.spacingMd,
          vertical: SlowverbTokens.spacingSm,
        ),
      ),
      icon: const Icon(Icons.headphones, size: 20),
      label: const Text('Preview Full'),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ChromeIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: SlowverbColors.textPrimary),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
}
