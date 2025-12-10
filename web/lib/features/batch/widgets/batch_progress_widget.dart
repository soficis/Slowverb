/*
 * Copyright (C) 2025 Slowverb Web
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:flutter/material.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';

/// Reusable widget for visualizing batch processing progress
///
/// Shows:
/// - Circular overall progress indicator with percentage
/// - Estimated time remaining
/// - Files completed counter
/// - Success rate
class BatchProgressWidget extends StatelessWidget {
  final BatchRenderProgress progress;
  final bool showDetails;

  const BatchProgressWidget({
    super.key,
    required this.progress,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular progress with percentage
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.overallProgress,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      Text(
                        '${(progress.overallProgress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.isFinished ? 'Completed' : 'Processing...',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${progress.completedFiles} of ${progress.totalFiles} files',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (!progress.isFinished &&
                          progress.currentFileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Current: ${progress.currentFileName}',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (showDetails) ...[
              const Divider(height: 32),

              // Detailed stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    icon: Icons.check_circle,
                    label: 'Success',
                    value: progress.completedFiles.toString(),
                    color: Colors.green,
                  ),
                  if (progress.failedFiles > 0)
                    _buildStatItem(
                      context,
                      icon: Icons.error,
                      label: 'Failed',
                      value: progress.failedFiles.toString(),
                      color: Colors.red,
                    ),
                  _buildStatItem(
                    context,
                    icon: Icons.pending,
                    label: 'Remaining',
                    value: progress.remainingFiles.toString(),
                    color: Colors.grey,
                  ),
                ],
              ),

              // Time estimation
              if (progress.estimatedTimeRemaining != null &&
                  !progress.isFinished)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated time remaining: ${_formatDuration(progress.estimatedTimeRemaining!)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

              // Success rate (when finished)
              if (progress.isFinished && progress.totalFiles > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Icon(
                        progress.successRate == 1.0
                            ? Icons.verified
                            : Icons.info,
                        size: 20,
                        color: progress.successRate == 1.0
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Success rate: ${(progress.successRate * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: progress.successRate == 1.0
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
