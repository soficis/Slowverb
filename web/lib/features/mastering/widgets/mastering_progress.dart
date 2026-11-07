import 'package:flutter/material.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';
import 'package:slowverb_web/providers/mastering_provider.dart';

/// Progress view for mastering operation
class MasteringProgressView extends StatelessWidget {
  final MasteringState state;
  final VoidCallback? onCancel;
  final VoidCallback? onForceStop;

  const MasteringProgressView({
    super.key,
    required this.state,
    this.onCancel,
    this.onForceStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        state.progress ?? MasteringProgress.initial(state.fileCount);
    final percent = (progress.percent * 100).round();
    final stage = _getStageText(state.status);

    return RetroWindow(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (stage.isNotEmpty)
                Annunciator(
                  stage.toUpperCase(),
                  lit: true,
                  color: SlowverbTokens.vfdAmber,
                ),
              const Spacer(),
              VfdPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SegmentReadout('$percent', size: 28),
                    const SizedBox(width: 2),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: VfdText('%', size: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          LinearProgressIndicator(
            value: progress.percent,
            minHeight: 12,
          ),
          if (progress.currentFileName.isNotEmpty) ...[
            const SizedBox(height: SlowverbTokens.spacingSm),
            Text(
              'Current: ${progress.currentFileName}',
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '(${progress.currentFileIndex} of ${progress.totalFiles})',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: SlowverbTokens.spacingSm),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Stage:', style: theme.textTheme.bodySmall),
              VfdText(progress.stage, size: 12),
            ],
          ),
          if (progress.estimatedTimeRemaining != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Estimated:', style: theme.textTheme.bodySmall),
                VfdText(
                  _formatDuration(progress.estimatedTimeRemaining!),
                  size: 12,
                ),
                Text('remaining', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
          if (progress.totalFiles > 1) ...[
            const SizedBox(height: SlowverbTokens.spacingLg),
            _buildFileStatusList(context, progress),
          ],
          const SizedBox(height: SlowverbTokens.spacingLg),
          Wrap(
            spacing: SlowverbTokens.spacingSm,
            runSpacing: SlowverbTokens.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              HwKey(
                onPressed: onCancel,
                icon: Icons.cancel,
                label: 'Cancel',
                style: HwKeyStyle.danger,
              ),
              HwKey(
                onPressed: onForceStop,
                icon: Icons.stop,
                label: 'Force stop all',
                style: HwKeyStyle.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileStatusList(
    BuildContext context,
    MasteringProgress progress,
  ) {
    return Faceplate(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (var index = 0; index < state.queuedFiles.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _buildFileStatusRow(context, index, progress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatusRow(
    BuildContext context,
    int index,
    MasteringProgress progress,
  ) {
    final theme = Theme.of(context);
    final file = state.queuedFiles[index];
    final status = file.status;
    final isCurrent = index + 1 == progress.currentFileIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingSm,
        vertical: 6,
      ),
      child: Row(
        children: [
          _buildStatusIcon(status, isCurrent),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Expanded(
            child: Text(
              file.fileName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _statusTextColor(status),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Annunciator(
            _getStatusText(status),
            lit: status != FileProcessStatus.pending,
            color: _statusColor(status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(FileProcessStatus status, bool isCurrent) {
    switch (status) {
      case FileProcessStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: SlowverbTokens.success,
          size: 18,
        );
      case FileProcessStatus.processing:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCurrent ? SlowverbTokens.vfdCyan : SlowverbTokens.textHint,
            ),
          ),
        );
      case FileProcessStatus.failed:
        return const Icon(
          Icons.error,
          color: SlowverbTokens.error,
          size: 18,
        );
      case FileProcessStatus.pending:
        return const Icon(
          Icons.circle_outlined,
          color: SlowverbTokens.textHint,
          size: 18,
        );
    }
  }

  Color _statusColor(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.completed:
        return SlowverbTokens.success;
      case FileProcessStatus.processing:
        return SlowverbTokens.vfdAmber;
      case FileProcessStatus.failed:
        return SlowverbTokens.error;
      case FileProcessStatus.pending:
        return SlowverbTokens.textHint;
    }
  }

  Color _statusTextColor(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.completed:
        return SlowverbTokens.textPrimary;
      case FileProcessStatus.processing:
        return SlowverbTokens.vfdCyan;
      case FileProcessStatus.failed:
        return SlowverbTokens.error;
      case FileProcessStatus.pending:
        return SlowverbTokens.textHint;
    }
  }

  String _getStatusText(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.completed:
        return 'DONE';
      case FileProcessStatus.processing:
        return 'RENDERING';
      case FileProcessStatus.failed:
        return 'FAILED';
      case FileProcessStatus.pending:
        return 'QUEUED';
    }
  }

  String _getStageText(MasteringStatus status) {
    switch (status) {
      case MasteringStatus.analyzing:
        return 'Analyzing';
      case MasteringStatus.mastering:
        return 'Mastering';
      case MasteringStatus.encoding:
        return 'Encoding';
      case MasteringStatus.zipping:
        return 'Zipping';
      default:
        return '';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes min $seconds sec';
    }
    return '$seconds seconds';
  }
}
