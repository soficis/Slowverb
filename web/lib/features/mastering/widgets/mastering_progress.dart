import 'package:flutter/material.dart';
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
    final progress =
        state.progress ?? MasteringProgress.initial(state.fileCount);
    final percent = (progress.percent * 100).round();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular progress
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: progress.percent,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.purple,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getStageText(state.status),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Current file info
              if (progress.currentFileName.isNotEmpty) ...[
                Text(
                  'Current: ${progress.currentFileName}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '(${progress.currentFileIndex} of ${progress.totalFiles})',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Stage: ${progress.stage}',
                style: const TextStyle(color: Colors.purple, fontSize: 14),
              ),

              // Estimated time
              if (progress.estimatedTimeRemaining != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Estimated: ${_formatDuration(progress.estimatedTimeRemaining!)} remaining',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 32),

              // File status list
              if (progress.totalFiles > 1) _buildFileStatusList(progress),

              const SizedBox(height: 32),

              // Cancel button
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                child: const Text('CANCEL'),
              ),
              const SizedBox(height: 12),
              // Force Stop button
              ElevatedButton(
                onPressed: onForceStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('FORCE STOP ALL'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatusList(MasteringProgress progress) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(state.queuedFiles.length, (index) {
            final file = state.queuedFiles[index];
            final status = file.status;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _buildStatusIcon(
                    status,
                    index + 1 == progress.currentFileIndex,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file.fileName,
                      style: TextStyle(
                        color: status == FileProcessStatus.completed
                            ? Colors.white70
                            : status == FileProcessStatus.processing
                            ? Colors.purple
                            : Colors.white38,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: status == FileProcessStatus.completed
                          ? Colors.green
                          : status == FileProcessStatus.processing
                          ? Colors.purple
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(FileProcessStatus status, bool isCurrent) {
    switch (status) {
      case FileProcessStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case FileProcessStatus.processing:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCurrent ? Colors.purple : Colors.white38,
            ),
          ),
        );
      case FileProcessStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 18);
      case FileProcessStatus.pending:
        return Icon(
          Icons.circle_outlined,
          color: Colors.white.withValues(alpha: 0.3),
          size: 18,
        );
    }
  }

  String _getStatusText(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.completed:
        return 'Done';
      case FileProcessStatus.processing:
        return 'Mastering...';
      case FileProcessStatus.failed:
        return 'Failed';
      case FileProcessStatus.pending:
        return 'Pending';
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
