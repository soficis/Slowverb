import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/features/batch/widgets/batch_progress_widget.dart';
import 'package:slowverb_web/providers/batch_export_provider.dart';

/// Screen for batch processing and exporting multiple audio files
class BatchExportScreen extends ConsumerWidget {
  const BatchExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(batchExportProvider);

    return Scaffold(
      backgroundColor: SlowverbColors.backgroundDark,
      appBar: AppBar(
        title: const Text('BATCH EXPORT'),
        actions: [
          if (state.queuedFiles.isNotEmpty &&
              state.status == BatchExportStatus.idle)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear all files',
              onPressed: () =>
                  ref.read(batchExportProvider.notifier).clearQueue(),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(24),
            child: _buildContent(context, ref, state),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    // Show progress view when running or completed
    if (state.status == BatchExportStatus.running ||
        state.status == BatchExportStatus.paused) {
      return _buildProgressView(context, ref, state);
    }

    if (state.status == BatchExportStatus.completed && state.progress != null) {
      return _buildCompletedView(context, ref, state);
    }

    // Show configuration view otherwise
    return _buildConfigurationView(context, ref, state);
  }

  Widget _buildConfigurationView(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: SlowverbColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            ShaderMask(
              shaderCallback: (bounds) =>
                  SlowverbColors.primaryGradient.createShader(bounds),
              child: Text(
                'BATCH EXPORT',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 3.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Process multiple files with the same effects',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Add files button
            _buildAddFilesButton(context, ref, state),

            const SizedBox(height: 16),

            // File list
            if (state.queuedFiles.isNotEmpty) ...[
              _buildFileList(context, ref, state),
              const SizedBox(height: 24),
            ],

            // Format selector
            _buildFormatSelector(context, ref, state),

            const SizedBox(height: 24),

            // Format-specific settings
            _buildFormatSettings(context, ref, state),

            const SizedBox(height: 24),

            // Preset selector
            _buildPresetSelector(context, ref, state),

            const SizedBox(height: 24),

            // Error message
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SlowverbColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: SlowverbColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SlowverbColors.error,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          ref.read(batchExportProvider.notifier).clearError(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Start button
            ElevatedButton.icon(
              onPressed: state.canStart
                  ? () => ref.read(batchExportProvider.notifier).startBatch()
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow, size: 24),
              label: Text(
                state.queuedFiles.isEmpty
                    ? 'ADD FILES TO START'
                    : 'EXPORT ${state.fileCount} FILES AS ${state.selectedFormat.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFilesButton(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _pickFiles(ref),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 24),
        side: BorderSide(
          color: SlowverbColors.primaryPurple.withValues(alpha: 0.5),
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.add, size: 28),
      label: Column(
        children: [
          const Text(
            '+ ADD AUDIO FILES',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Select multiple MP3, WAV, or FLAC files',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'wav',
        'flac',
        'aac',
        'm4a',
        'ogg',
        'aiff',
        'aif',
      ],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final files = result.files
        .where((f) => f.bytes != null)
        .map((f) => (fileName: f.name, bytes: f.bytes!))
        .toList();

    await ref.read(batchExportProvider.notifier).addFiles(files);
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: SlowverbColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: state.queuedFiles.length,
        itemBuilder: (context, index) {
          final file = state.queuedFiles[index];
          return ListTile(
            leading: const Icon(Icons.audio_file),
            title: Text(file.fileName, overflow: TextOverflow.ellipsis),
            subtitle: Row(
              children: [
                _buildFormatBadge(file.metadata.format, file.isLossless),
                const SizedBox(width: 8),
                if (file.metadata.duration != null)
                  Text(_formatDuration(file.metadata.duration!)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => ref
                  .read(batchExportProvider.notifier)
                  .removeFile(file.fileId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormatBadge(String format, bool isLossless) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isLossless ? SlowverbColors.accentMint : SlowverbColors.warning)
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              (isLossless ? SlowverbColors.accentMint : SlowverbColors.warning)
                  .withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        format.toUpperCase(),
        style: TextStyle(
          color: isLossless
              ? SlowverbColors.accentMint
              : SlowverbColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormatSelector(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FORMAT', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            if (!state.allFilesLossless && state.queuedFiles.isNotEmpty)
              Tooltip(
                message:
                    'Some files are lossy. FLAC export requires all lossless sources.',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: SlowverbColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mixed formats',
                      style: TextStyle(
                        color: SlowverbColors.warning,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFormatButton(
              context,
              ref,
              state,
              format: 'mp3',
              label: 'MP3',
              icon: Icons.music_note,
            ),
            const SizedBox(width: 8),
            _buildFormatButton(
              context,
              ref,
              state,
              format: 'aac',
              label: 'AAC',
              icon: Icons.high_quality_outlined,
            ),
            const SizedBox(width: 8),
            _buildFormatButton(
              context,
              ref,
              state,
              format: 'wav',
              label: 'WAV',
              icon: Icons.graphic_eq,
            ),
            const SizedBox(width: 8),
            _buildFlacButton(context, ref, state),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatButton(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state, {
    required String format,
    required String label,
    required IconData icon,
  }) {
    final isSelected = state.selectedFormat == format;

    return Expanded(
      child: InkWell(
        onTap: () => ref.read(batchExportProvider.notifier).setFormat(format),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? SlowverbColors.primaryPurple.withValues(alpha: 0.2)
                : SlowverbColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? SlowverbColors.primaryPurple
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? SlowverbColors.primaryPurple : null,
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlacButton(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    final isEnabled = state.isFlacEnabled;
    final isSelected = state.selectedFormat == 'flac';

    final button = Expanded(
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: InkWell(
          onTap: isEnabled
              ? () => ref.read(batchExportProvider.notifier).setFormat('flac')
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected && isEnabled
                  ? SlowverbColors.primaryPurple.withValues(alpha: 0.2)
                  : SlowverbColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected && isEnabled
                    ? SlowverbColors.primaryPurple
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.high_quality,
                  color: isSelected && isEnabled
                      ? SlowverbColors.primaryPurple
                      : null,
                ),
                const SizedBox(height: 4),
                const Text(
                  'FLAC',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isEnabled && state.queuedFiles.isNotEmpty) {
      return Tooltip(
        message:
            'FLAC export requires all files to be lossless sources (WAV, FLAC, AIFF).',
        child: button,
      );
    }

    return button;
  }

  Widget _buildFormatSettings(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    switch (state.selectedFormat) {
      case 'mp3':
        return _buildBitrateSlider(
          context,
          ref,
          label: 'MP3 BITRATE',
          value: state.mp3Bitrate,
          min: 128,
          max: 320,
          divisions: 3,
          onChanged: (v) =>
              ref.read(batchExportProvider.notifier).setMp3Bitrate(v),
        );
      case 'aac':
        return _buildBitrateSlider(
          context,
          ref,
          label: 'AAC BITRATE',
          value: state.aacBitrate,
          min: 128,
          max: 256,
          divisions: 2,
          onChanged: (v) =>
              ref.read(batchExportProvider.notifier).setAacBitrate(v),
        );
      case 'flac':
        return _buildCompressionSlider(context, ref, state);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBitrateSlider(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required void Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: divisions,
                label: '$value kbps',
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SlowverbColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value kbps',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SlowverbColors.accentPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompressionSlider(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FLAC COMPRESSION LEVEL',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: state.flacCompressionLevel.toDouble(),
                min: 0,
                max: 8,
                divisions: 8,
                label: 'Level ${state.flacCompressionLevel}',
                onChanged: (v) => ref
                    .read(batchExportProvider.notifier)
                    .setFlacCompressionLevel(v.toInt()),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SlowverbColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Level ${state.flacCompressionLevel}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SlowverbColors.accentCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetSelector(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EFFECT PRESET', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: state.selectedPreset.id,
          decoration: InputDecoration(
            filled: true,
            fillColor: SlowverbColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          items: Presets.all.map((preset) {
            return DropdownMenuItem(value: preset.id, child: Text(preset.name));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              final preset = Presets.getById(value);
              if (preset != null) {
                ref.read(batchExportProvider.notifier).setPreset(preset);
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildProgressView(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.progress != null)
            BatchProgressWidget(progress: state.progress!),

          const SizedBox(height: 24),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.status == BatchExportStatus.running)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(batchExportProvider.notifier).pauseBatch(),
                  icon: const Icon(Icons.pause),
                  label: const Text('PAUSE'),
                ),
              if (state.status == BatchExportStatus.paused)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(batchExportProvider.notifier).resumeBatch(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('RESUME'),
                ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () =>
                    ref.read(batchExportProvider.notifier).cancelBatch(),
                icon: const Icon(Icons.cancel),
                label: const Text('CANCEL'),
                style: TextButton.styleFrom(
                  foregroundColor: SlowverbColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    final progress = state.progress!;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SlowverbColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            progress.failedFiles == 0 ? Icons.check_circle : Icons.warning,
            size: 64,
            color: progress.failedFiles == 0
                ? SlowverbColors.accentMint
                : SlowverbColors.warning,
          ),

          const SizedBox(height: 16),

          Text(
            progress.failedFiles == 0
                ? 'BATCH COMPLETE'
                : 'BATCH FINISHED WITH ERRORS',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 8),

          Text(
            '${progress.completedFiles} of ${progress.totalFiles} files exported successfully',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          if (progress.errors.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: SlowverbColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: progress.errors.length,
                itemBuilder: (context, index) {
                  final entry = progress.errors.entries.elementAt(index);
                  return ListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      color: SlowverbColors.error,
                    ),
                    title: Text(entry.key),
                    subtitle: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          ElevatedButton.icon(
            onPressed: () => ref.read(batchExportProvider.notifier).reset(),
            icon: const Icon(Icons.refresh),
            label: const Text('START NEW BATCH'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
