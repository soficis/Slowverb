import 'package:flutter/material.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/batch_render_progress.dart';

/// Reusable widget for visualizing batch processing progress
///
/// Shows:
/// - Overall progress indicator with percentage
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
    final theme = Theme.of(context);
    final percent = (progress.overallProgress * 100).toInt();
    final isFinished = progress.isFinished;
    final hasFailed = progress.failedFiles > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Annunciator(
              isFinished ? (hasFailed ? 'FAILED' : 'DONE') : 'RENDERING',
              lit: true,
              color: isFinished
                  ? (hasFailed
                        ? SlowverbTokens.error
                        : SlowverbTokens.success)
                  : SlowverbTokens.vfdAmber,
            ),
            const Spacer(),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: _buildPercentReadout(percent),
            ),
          ],
        ),
        const SizedBox(height: SlowverbTokens.spacingSm),
        LinearProgressIndicator(
          value: progress.overallProgress,
          minHeight: 12,
        ),
        const SizedBox(height: SlowverbTokens.spacingSm),
        Text(
          '${progress.completedFiles} of ${progress.totalFiles} files',
          style: theme.textTheme.bodyLarge,
        ),
        if (!isFinished && progress.currentFileName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Current: ${progress.currentFileName}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (showDetails) ...[
          const Divider(height: SlowverbTokens.spacingLg),
          Wrap(
            spacing: SlowverbTokens.spacingLg,
            runSpacing: SlowverbTokens.spacingMd,
            alignment: WrapAlignment.center,
            children: [
              _buildStatItem(
                icon: Icons.check_circle,
                label: 'Success',
                value: '${progress.completedFiles}',
                color: SlowverbTokens.success,
              ),
              if (progress.failedFiles > 0)
                _buildStatItem(
                  icon: Icons.error,
                  label: 'Failed',
                  value: '${progress.failedFiles}',
                  color: SlowverbTokens.error,
                ),
              _buildStatItem(
                icon: Icons.pending,
                label: 'Remaining',
                value: '${progress.remainingFiles}',
                color: SlowverbTokens.textHint,
              ),
            ],
          ),
          if (progress.estimatedTimeRemaining != null && !isFinished)
            Padding(
              padding: const EdgeInsets.only(top: SlowverbTokens.spacingMd),
              child: Wrap(
                spacing: SlowverbTokens.spacingSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Estimated time remaining:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  VfdText(
                    _formatDuration(progress.estimatedTimeRemaining!),
                    size: 14,
                  ),
                ],
              ),
            ),
          if (isFinished && progress.totalFiles > 0)
            Padding(
              padding: const EdgeInsets.only(top: SlowverbTokens.spacingMd),
              child: Wrap(
                spacing: SlowverbTokens.spacingSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    progress.successRate == 1.0
                        ? Icons.verified
                        : Icons.info,
                    size: 16,
                    color: progress.successRate == 1.0
                        ? SlowverbTokens.success
                        : SlowverbTokens.warning,
                  ),
                  Text(
                    'Success rate:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  VfdText(
                    '${(progress.successRate * 100).toInt()}%',
                    size: 14,
                    color: progress.successRate == 1.0
                        ? SlowverbTokens.success
                        : SlowverbTokens.warning,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPercentReadout(int percent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SegmentReadout('$percent', size: 20),
        const SizedBox(width: 2),
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: VfdText('%', size: 11),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        SegmentReadout(value, size: 20, color: color),
        const SizedBox(height: 2),
        PlateLabel(label),
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
