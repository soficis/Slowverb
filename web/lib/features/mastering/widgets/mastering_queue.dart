import 'package:flutter/material.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';

/// Widget displaying the mastering file queue
class MasteringQueue extends StatelessWidget {
  final List<MasteringQueueFile> files;
  final ValueChanged<String> onRemoveFile;
  final VoidCallback onClearAll;
  final VoidCallback onAddMore;

  const MasteringQueue({
    super.key,
    required this.files,
    required this.onRemoveFile,
    required this.onClearAll,
    required this.onAddMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: SlowverbTokens.spacingSm,
          runSpacing: SlowverbTokens.spacingSm,
          children: [
            HwKey(
              onPressed: onAddMore,
              icon: Icons.add,
              label: 'Add more',
            ),
            HwKey(
              onPressed: onClearAll,
              icon: Icons.clear_all,
              label: 'Clear all',
              style: HwKeyStyle.danger,
            ),
          ],
        ),
        const SizedBox(height: SlowverbTokens.spacingSm),
        Faceplate(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildFileRow(context, files[i]),
              ],
            ],
          ),
        ),
        // Warning if batch contains lossy files
        if (!files.every((f) => f.isLossless) && files.isNotEmpty) ...[
          const SizedBox(height: SlowverbTokens.spacingSm),
          VfdPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: SlowverbTokens.warning,
                ),
                const SizedBox(width: SlowverbTokens.spacingSm),
                Expanded(
                  child: Text(
                    'Batch contains lossy files. FLAC export disabled.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SlowverbTokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileRow(BuildContext context, MasteringQueueFile file) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingSm,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file,
            size: 20,
            color: SlowverbTokens.textSecondary,
          ),
          const SizedBox(width: SlowverbTokens.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: SlowverbTokens.spacingSm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    VfdText(
                      _formatDuration(file.metadata.duration),
                      size: 12,
                    ),
                    _buildFormatBadge(file),
                    VfdText(
                      _formatSampleRate(file.metadata.sampleRate),
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SlowverbTokens.spacingSm),
          HwKey(
            onPressed: () => onRemoveFile(file.fileId),
            icon: Icons.close,
            tooltip: 'Remove file',
            style: HwKeyStyle.danger,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(MasteringQueueFile file) {
    final format = _extractFormat(file.fileName).toUpperCase();
    final isLossless = file.isLossless;
    final color = isLossless ? SlowverbTokens.success : SlowverbTokens.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VfdText(format, size: 12, color: color),
        const SizedBox(width: 4),
        Icon(
          isLossless ? Icons.check_circle : Icons.warning,
          size: 14,
          color: color,
        ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSampleRate(int sampleRate) {
    if (sampleRate >= 1000) {
      return '${(sampleRate / 1000).toStringAsFixed(1)}kHz';
    }
    return '${sampleRate}Hz';
  }

  String _extractFormat(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last;
    }
    return 'unknown';
  }
}
