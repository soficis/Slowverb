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

/// Track information header for the editor screen
class TrackHeader extends StatelessWidget {
  final String trackName;
  final String artistName;
  final String presetName;
  final Duration duration;

  const TrackHeader({
    super.key,
    required this.trackName,
    required this.artistName,
    required this.presetName,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildAlbumArt(),
          const SizedBox(width: 16),
          Expanded(child: _buildTrackInfo(context)),
        ],
      ),
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: SlowverbColors.vaporwaveSunset,
        boxShadow: [
          BoxShadow(
            color: SlowverbColors.hotPink.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 40,
        shadows: [Shadow(color: SlowverbColors.deepPurple, blurRadius: 8)],
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext context) {
    final mins = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    final durationText = '$mins:${secs.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trackName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            shadows: [
              const Shadow(color: SlowverbColors.hotPink, blurRadius: 10),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          artistName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: SlowverbColors.neonCyan.withValues(alpha: 0.8),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SlowverbColors.deepPurple,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: SlowverbColors.hotPink.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: SlowverbColors.hotPink.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                presetName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SlowverbColors.hotPink,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(color: SlowverbColors.hotPink, blurRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              durationText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
