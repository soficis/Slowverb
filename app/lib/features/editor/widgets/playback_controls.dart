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
import 'package:slowverb/app/widgets/vaporwave_widgets.dart';

/// Playback control buttons for the editor
class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool isProcessing;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onLoop;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    this.isProcessing = false,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onLoop,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loop button (secondary)
          IconButton(
            onPressed: onLoop,
            icon: const Icon(Icons.repeat),
            iconSize: 24,
            color: SlowverbColors.neonCyan.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 24),
          // Seek backward
          IconButton(
            onPressed: onSeekBackward,
            icon: const Icon(Icons.replay_10),
            iconSize: 32,
            color: SlowverbColors.neonCyan,
            style: IconButton.styleFrom(
              shadowColor: SlowverbColors.neonCyan,
              elevation: 4,
            ),
          ),
          const SizedBox(width: 24),
          // Play/Pause (Primary Neon)
          _buildPlayButton(),
          const SizedBox(width: 24),
          // Seek forward
          IconButton(
            onPressed: onSeekForward,
            icon: const Icon(Icons.forward_10),
            iconSize: 32,
            color: SlowverbColors.neonCyan,
            style: IconButton.styleFrom(
              shadowColor: SlowverbColors.neonCyan,
              elevation: 4,
            ),
          ),
          const SizedBox(width: 24),
          // Placeholder for balance (Loop match)
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.shuffle), // Or another icon
            iconSize: 24,
            color: Colors.transparent, // Invisible
            disabledColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: onPlayPause,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SlowverbColors.vaporwaveSunset,
          boxShadow: [
            BoxShadow(
              color: SlowverbColors.hotPink.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: SlowverbColors.neonCyan.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isProcessing)
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
