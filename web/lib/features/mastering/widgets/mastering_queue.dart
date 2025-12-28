import 'package:flutter/material.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FILES (${files.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white54,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onAddMore,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add More'),
                  style: TextButton.styleFrom(foregroundColor: Colors.purple),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade300,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // File list
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            itemBuilder: (context, index) => _buildFileRow(files[index]),
          ),
        ),

        // Warning if batch contains lossy files
        if (!files.every((f) => f.isLossless) && files.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Batch contains lossy files. FLAC export disabled.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileRow(MasteringQueueFile file) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // File icon
          const Icon(Icons.insert_drive_file, size: 20, color: Colors.white54),
          const SizedBox(width: 12),

          // File name
          Expanded(
            flex: 3,
            child: Text(
              file.fileName,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Duration
          Expanded(
            child: Text(
              _formatDuration(file.metadata.duration),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // Format badge
          SizedBox(width: 80, child: _buildFormatBadge(file)),

          // Sample rate
          SizedBox(
            width: 70,
            child: Text(
              _formatSampleRate(file.metadata.sampleRate),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () => onRemoveFile(file.fileId),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white38,
            hoverColor: Colors.red.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(MasteringQueueFile file) {
    final format = _extractFormat(file.fileName).toUpperCase();
    final isLossless = file.isLossless;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isLossless
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.yellow.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            format,
            style: TextStyle(
              color: isLossless ? Colors.green : Colors.yellow,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          isLossless ? Icons.check_circle : Icons.warning,
          size: 14,
          color: isLossless ? Colors.green : Colors.orange,
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
