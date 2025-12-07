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

/// Card widget displaying a project in the library list
class ProjectCard extends StatelessWidget {
  final String title;
  final String presetName;
  final Duration duration;
  final DateTime lastModified;
  final VoidCallback onTap;
  final bool isCurrentSession;

  const ProjectCard({
    super.key,
    required this.title,
    required this.presetName,
    required this.duration,
    required this.lastModified,
    required this.onTap,
    this.isCurrentSession = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: isCurrentSession
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SlowverbColors.neonCyan, width: 2),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildThumbnail(),
                const SizedBox(width: 16),
                Expanded(child: _buildInfo(context)),
                _buildDuration(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _getGradientForPreset(),
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 28),
    );
  }

  Gradient _getGradientForPreset() {
    switch (presetName) {
      case 'Slowed + Reverb':
        return SlowverbColors.slowedReverbGradient;
      case 'Vaporwave Chill':
        return SlowverbColors.vaporwaveChillGradient;
      case 'Nightcore':
        return SlowverbColors.nightcoreGradient;
      case 'Echo Slow':
        return SlowverbColors.echoSlowGradient;
      default:
        return SlowverbColors.slowedReverbGradient;
    }
  }

  Widget _buildInfo(BuildContext context) {
    final timeAgo = _formatTimeAgo(lastModified);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentSession)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SlowverbColors.neonCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: SlowverbColors.neonCyan,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          presetName,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: SlowverbColors.lavender),
        ),
        const SizedBox(height: 2),
        Text(
          timeAgo,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: SlowverbColors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDuration(BuildContext context) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final formatted = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Text(formatted, style: Theme.of(context).textTheme.labelLarge);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
