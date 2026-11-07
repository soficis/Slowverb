import 'dart:typed_data';
import 'dart:js_interop';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/features/batch/widgets/batch_progress_widget.dart';
import 'package:slowverb_web/providers/batch_export_provider.dart';
import 'package:web/web.dart' as web;

/// Screen for batch processing and exporting multiple audio files
class BatchExportScreen extends ConsumerStatefulWidget {
  const BatchExportScreen({super.key});

  @override
  ConsumerState<BatchExportScreen> createState() => _BatchExportScreenState();
}

class _BatchExportScreenState extends ConsumerState<BatchExportScreen> {
  bool _isHoveringFiles = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchExportProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final padding = isNarrow
        ? SlowverbTokens.spacingMd
        : SlowverbTokens.spacingXl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch export'),
        leading: const BackButton(),
        actions: [
          if (state.queuedFiles.isNotEmpty &&
              state.status == BatchExportStatus.idle)
            Padding(
              padding: const EdgeInsets.only(right: SlowverbTokens.spacingSm),
              child: Center(
                child: HwKey(
                  onPressed: () =>
                      ref.read(batchExportProvider.notifier).clearQueue(),
                  icon: Icons.delete_outline,
                  tooltip: 'Clear all files',
                  style: HwKeyStyle.danger,
                  size: 36,
                ),
              ),
            ),
        ],
      ),
      body: DropTarget(
        onDragDone: (details) async {
          setState(() => _isHoveringFiles = false);

          if (details.files.isEmpty) return;

          final files = <({String fileName, Uint8List bytes})>[];
          for (final file in details.files) {
            // Basic extension check
            final ext = file.name.split('.').last.toLowerCase();
            if ([
              'mp3',
              'wav',
              'flac',
              'aac',
              'm4a',
              'ogg',
              'aiff',
              'aif',
            ].contains(ext)) {
              final bytes = await file.readAsBytes();
              files.add((fileName: file.name, bytes: bytes));
            }
          }

          if (files.isNotEmpty) {
            await ref.read(batchExportProvider.notifier).addFiles(files);
          }
        },
        onDragEntered: (_) => setState(() => _isHoveringFiles = true),
        onDragExited: (_) => setState(() => _isHoveringFiles = false),
        child: RetroDesktop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_buildContent(context, ref, state)],
                  ),
                ),
              ),
            ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RetroWindow(
          title: 'Files',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Process multiple files with the same effects',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              _buildAddFilesButton(context, ref, state),
              if (state.queuedFiles.isNotEmpty) ...[
                const SizedBox(height: SlowverbTokens.spacingMd),
                _buildFileList(context, ref, state),
              ],
            ],
          ),
        ),
        const SizedBox(height: SlowverbTokens.spacingMd),
        RetroWindow(
          title: 'Format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PlateLabel('Output format'),
                  const Spacer(),
                  if (!state.allFilesLossless && state.queuedFiles.isNotEmpty)
                    Tooltip(
                      message:
                          'Some files are lossy. FLAC export requires all lossless sources.',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: SlowverbTokens.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mixed formats',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SlowverbTokens.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SlowverbTokens.spacingSm),
              _buildFormatSelector(context, ref, state),
              if (state.selectedFormat != 'wav') ...[
                const Divider(height: SlowverbTokens.spacingLg),
                _buildFormatSettings(context, ref, state),
              ],
            ],
          ),
        ),
        const SizedBox(height: SlowverbTokens.spacingMd),
        RetroWindow(
          title: 'Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPresetSelector(context, ref, state),
              if (state.showZipOption) ...[
                const SizedBox(height: SlowverbTokens.spacingMd),
                _buildZipExportToggle(context, ref, state),
              ],
            ],
          ),
        ),
        const SizedBox(height: SlowverbTokens.spacingMd),
        RetroWindow(
          title: 'Export',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.errorMessage != null) ...[
                VfdPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: SlowverbTokens.error,
                        size: 18,
                      ),
                      const SizedBox(width: SlowverbTokens.spacingSm),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SlowverbTokens.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: SlowverbTokens.spacingSm),
                      HwKey(
                        onPressed: () => ref
                            .read(batchExportProvider.notifier)
                            .clearError(),
                        icon: Icons.close,
                        tooltip: 'Dismiss error',
                        style: HwKeyStyle.danger,
                        size: 28,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SlowverbTokens.spacingMd),
              ],
              HwKey(
                onPressed: state.canStart
                    ? () => ref.read(batchExportProvider.notifier).startBatch()
                    : null,
                icon: Icons.play_arrow,
                label: state.queuedFiles.isEmpty
                    ? 'Add files to start'
                    : 'Export ${state.fileCount} files as ${state.selectedFormat.toUpperCase()}',
                style: HwKeyStyle.primary,
                isDefault: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddFilesButton(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) async {
        if (details.files.isEmpty) return;

        final files = <({String fileName, Uint8List bytes})>[];
        for (final file in details.files) {
          // Basic extension check
          final ext = file.name.split('.').last.toLowerCase();
          if ([
            'mp3',
            'wav',
            'flac',
            'aac',
            'm4a',
            'ogg',
            'aiff',
            'aif',
          ].contains(ext)) {
            final bytes = await file.readAsBytes();
            files.add((fileName: file.name, bytes: bytes));
          }
        }

        if (files.isNotEmpty) {
          await ref.read(batchExportProvider.notifier).addFiles(files);
        }
      },
      child: InkWell(
        onTap: () => _pickFiles(ref),
        borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
            border: Border.all(
              color: _isHoveringFiles
                  ? SlowverbTokens.vfdCyan
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: VfdPanel(
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    size: 40,
                    color: _isHoveringFiles
                        ? SlowverbTokens.vfdCyan
                        : SlowverbTokens.textSecondary,
                  ),
                  const SizedBox(height: SlowverbTokens.spacingSm),
                  const VfdText(
                    'Drop files here or click to browse',
                    size: 18,
                    maxLines: 2,
                  ),
                  const SizedBox(height: SlowverbTokens.spacingXs),
                  Text(
                    'Add audio files — MP3, WAV, FLAC, AAC, M4A, OGG, AIFF',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final theme = Theme.of(context);

    return Faceplate(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: state.queuedFiles.length,
          itemBuilder: (context, index) {
            final file = state.queuedFiles[index];

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SlowverbTokens.spacingSm,
                vertical: SlowverbTokens.spacingSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.audio_file,
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
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: SlowverbTokens.spacingSm,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildFormatBadge(
                              file.metadata.format,
                              file.isLossless,
                            ),
                            if (file.metadata.duration != null)
                              VfdText(
                                _formatDuration(file.metadata.duration!),
                                size: 12,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SlowverbTokens.spacingSm),
                  HwKey(
                    onPressed: () => ref
                        .read(batchExportProvider.notifier)
                        .removeFile(file.fileId),
                    icon: Icons.close,
                    tooltip: 'Remove file',
                    style: HwKeyStyle.danger,
                    size: 28,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormatBadge(String format, bool isLossless) {
    final color = isLossless ? SlowverbTokens.success : SlowverbTokens.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLossless ? Icons.high_quality : Icons.compress,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        VfdText(format.toUpperCase(), size: 12, color: color),
      ],
    );
  }

  Widget _buildFormatSelector(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    return Semantics(
      label: 'Export format',
      container: true,
      child: Wrap(
        spacing: SlowverbTokens.spacingSm,
        runSpacing: SlowverbTokens.spacingSm,
        children: [
          _buildFormatButton(ref, state, format: 'mp3', label: 'MP3'),
          _buildFormatButton(ref, state, format: 'aac', label: 'AAC'),
          _buildFormatButton(ref, state, format: 'wav', label: 'WAV'),
          _buildFlacButton(ref, state),
        ],
      ),
    );
  }

  Widget _buildFormatButton(
    WidgetRef ref,
    BatchExportState state, {
    required String format,
    required String label,
  }) {
    return HwKey(
      onPressed: () =>
          ref.read(batchExportProvider.notifier).setFormat(format),
      label: label,
      lit: state.selectedFormat == format,
      size: 32,
    );
  }

  Widget _buildFlacButton(WidgetRef ref, BatchExportState state) {
    final isEnabled = state.isFlacEnabled;

    return HwKey(
      onPressed: isEnabled
          ? () => ref.read(batchExportProvider.notifier).setFormat('flac')
          : null,
      label: 'FLAC',
      lit: state.selectedFormat == 'flac',
      size: 32,
      tooltip: !isEnabled && state.queuedFiles.isNotEmpty
          ? 'FLAC export requires all files to be lossless sources (WAV, FLAC, AIFF).'
          : null,
    );
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
          label: 'MP3 bitrate',
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
          label: 'AAC bitrate',
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
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required void Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlateLabel(label),
        const SizedBox(height: SlowverbTokens.spacingXs),
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
            const SizedBox(width: SlowverbTokens.spacingSm),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: _buildReadout('$value', 'kbps'),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlateLabel('FLAC compression level'),
        const SizedBox(height: SlowverbTokens.spacingXs),
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
            const SizedBox(width: SlowverbTokens.spacingSm),
            VfdPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: _buildReadout(
                '${state.flacCompressionLevel}',
                'level',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadout(String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SegmentReadout(value, size: 22),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: PlateLabel(unit),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlateLabel('Effect preset'),
        const SizedBox(height: SlowverbTokens.spacingSm),
        RetroSelect<String>(
          semanticLabel: 'Effect preset',
          value: state.selectedPreset.id,
          options: [
            for (final preset in Presets.all)
              RetroOption(preset.id, preset.name),
          ],
          onChanged: (value) {
            final preset = Presets.getById(value);
            if (preset != null) {
              ref.read(batchExportProvider.notifier).setPreset(preset);
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
    return RetroWindow(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.progress != null)
            BatchProgressWidget(progress: state.progress!),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Wrap(
            spacing: SlowverbTokens.spacingSm,
            runSpacing: SlowverbTokens.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              if (state.status == BatchExportStatus.running)
                HwKey(
                  onPressed: () =>
                      ref.read(batchExportProvider.notifier).pauseBatch(),
                  icon: Icons.pause,
                  label: 'Pause',
                ),
              if (state.status == BatchExportStatus.paused)
                HwKey(
                  onPressed: () =>
                      ref.read(batchExportProvider.notifier).resumeBatch(),
                  icon: Icons.play_arrow,
                  label: 'Resume',
                ),
              HwKey(
                onPressed: () =>
                    ref.read(batchExportProvider.notifier).cancelBatch(),
                icon: Icons.cancel,
                label: 'Cancel',
                style: HwKeyStyle.danger,
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
    final theme = Theme.of(context);
    final progress = state.progress!;
    final hasFailed = progress.failedFiles > 0;

    return RetroWindow(
      title: 'Results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Annunciator(
              hasFailed ? 'FAILED' : 'DONE',
              lit: true,
              color: hasFailed
                  ? SlowverbTokens.error
                  : SlowverbTokens.success,
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Text(
            hasFailed ? 'Batch finished with errors' : 'Batch complete',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingXs),
          Text(
            '${progress.completedFiles} of ${progress.totalFiles} files exported successfully',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          if (progress.errors.isNotEmpty) ...[
            Faceplate(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final entry in progress.errors.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SlowverbTokens.spacingSm,
                            vertical: SlowverbTokens.spacingSm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: SlowverbTokens.error,
                                size: 16,
                              ),
                              const SizedBox(width: SlowverbTokens.spacingSm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    Text(
                                      entry.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: SlowverbTokens.spacingLg),
          ],
          Wrap(
            spacing: SlowverbTokens.spacingSm,
            runSpacing: SlowverbTokens.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              if (state.zipExportEnabled && state.zipResult != null)
                HwKey(
                  onPressed: () => _downloadZip(state),
                  icon: Icons.archive,
                  label: 'Download ZIP',
                ),
              HwKey(
                onPressed: () =>
                    ref.read(batchExportProvider.notifier).reset(),
                icon: Icons.refresh,
                label: 'Start new batch',
              ),
            ],
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

  Widget _buildZipExportToggle(
    BuildContext context,
    WidgetRef ref,
    BatchExportState state,
  ) {
    final theme = Theme.of(context);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SlowverbTokens.spacingXs),
        child: Row(
          children: [
            const Icon(
              Icons.archive_outlined,
              size: 20,
              color: SlowverbTokens.textSecondary,
            ),
            const SizedBox(width: SlowverbTokens.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export as ZIP', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Bundle all exported files into a single zip archive',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: SlowverbTokens.spacingSm),
            Switch(
              value: state.zipExportEnabled,
              onChanged: (value) {
                if (value) {
                  ref.read(batchExportProvider.notifier).enableZipExport();
                } else {
                  ref.read(batchExportProvider.notifier).disableZipExport();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _downloadZip(BatchExportState state) {
    if (state.zipResult == null) return;
    _download(state.zipResult!, 'slowverb_batch_export.zip');
  }

  void _download(Uint8List bytes, String fileName) {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }
}
