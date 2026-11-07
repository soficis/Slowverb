import 'dart:js_interop';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_controls.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_progress.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_queue.dart';
import 'package:slowverb_web/providers/mastering_provider.dart';
import 'package:web/web.dart' as web;

/// Screen for PhaseLimiter mastering interface
class MasteringScreen extends ConsumerStatefulWidget {
  const MasteringScreen({super.key});

  @override
  ConsumerState<MasteringScreen> createState() => _MasteringScreenState();
}

class _MasteringScreenState extends ConsumerState<MasteringScreen> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masteringProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final padding = isNarrow
        ? SlowverbTokens.spacingMd
        : SlowverbTokens.spacingXl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mastering'),
        leading: const BackButton(),
      ),
      body: RetroDesktop(
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
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    switch (state.status) {
      case MasteringStatus.idle:
        return _buildConfigurationView(context, ref, state);
      case MasteringStatus.analyzing:
      case MasteringStatus.mastering:
      case MasteringStatus.encoding:
      case MasteringStatus.zipping:
        return MasteringProgressView(
          state: state,
          onCancel: () =>
              ref.read(masteringProvider.notifier).cancelMastering(),
          onForceStop: () =>
              ref.read(masteringProvider.notifier).forceStopAllMastering(),
        );
      case MasteringStatus.completed:
        return _buildCompletedView(context, ref, state);
      case MasteringStatus.error:
        return _buildErrorView(context, ref, state);
    }
  }

  Widget _buildConfigurationView(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    final theme = Theme.of(context);
    final hasFiles = state.queuedFiles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RetroWindow(
          title: hasFiles ? 'Files (${state.queuedFiles.length})' : 'Files',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Free and local browser-powered AI mastering',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: SlowverbTokens.spacingMd),
              if (!hasFiles)
                _buildDropZone(context, ref, state)
              else
                MasteringQueue(
                  files: state.queuedFiles,
                  onRemoveFile: (fileId) =>
                      ref.read(masteringProvider.notifier).removeFile(fileId),
                  onClearAll: () =>
                      ref.read(masteringProvider.notifier).clearQueue(),
                  onAddMore: () => _pickFiles(ref),
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: SlowverbTokens.spacingMd),
                VfdPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: SlowverbTokens.warning,
                        size: 18,
                      ),
                      const SizedBox(width: SlowverbTokens.spacingSm),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SlowverbTokens.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: SlowverbTokens.spacingSm),
                      HwKey(
                        onPressed: () =>
                            ref.read(masteringProvider.notifier).clearError(),
                        icon: Icons.close,
                        tooltip: 'Dismiss error',
                        style: HwKeyStyle.danger,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasFiles) ...[
          const SizedBox(height: SlowverbTokens.spacingMd),
          RetroWindow(
            title: 'Settings',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MasteringControls(
                  state: state,
                  onTargetLufsChanged: (v) =>
                      ref.read(masteringProvider.notifier).setTargetLufs(v),
                  onBassPreservationChanged: (v) => ref
                      .read(masteringProvider.notifier)
                      .setBassPreservation(v),
                  onFormatChanged: (f) =>
                      ref.read(masteringProvider.notifier).setFormat(f),
                  onModeChanged: (m) =>
                      ref.read(masteringProvider.notifier).setMode(m),
                  onMp3BitrateChanged: (b) =>
                      ref.read(masteringProvider.notifier).setMp3Bitrate(b),
                  onAacBitrateChanged: (b) =>
                      ref.read(masteringProvider.notifier).setAacBitrate(b),
                  onFlacCompressionChanged: (l) => ref
                      .read(masteringProvider.notifier)
                      .setFlacCompressionLevel(l),
                  onZipExportChanged: (enabled) {
                    if (enabled) {
                      ref.read(masteringProvider.notifier).enableZipExport();
                    } else {
                      ref.read(masteringProvider.notifier).disableZipExport();
                    }
                  },
                ),
                const SizedBox(height: SlowverbTokens.spacingMd),
                const Divider(height: 1),
                const SizedBox(height: SlowverbTokens.spacingMd),
                _buildStartButton(context, ref, state),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropZone(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDroppedFiles(ref, details.files);
      },
      child: GestureDetector(
        onTap: () => _pickFiles(ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SlowverbTokens.radiusSm),
            border: Border.all(
              color: _isDragging
                  ? SlowverbTokens.vfdCyan
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: VfdPanel(
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 56,
                    color: _isDragging
                        ? SlowverbTokens.vfdCyan
                        : SlowverbTokens.textSecondary,
                  ),
                  const SizedBox(height: SlowverbTokens.spacingMd),
                  const VfdText(
                    'Drop files here or click to browse',
                    size: 18,
                    maxLines: 2,
                  ),
                  const SizedBox(height: SlowverbTokens.spacingXs),
                  Text(
                    'Supports: MP3, WAV, FLAC, AAC, OGG',
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
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.bytes != null)
          .map((f) => (fileName: f.name, bytes: f.bytes!))
          .toList();

      await ref.read(masteringProvider.notifier).addFiles(files);
    }
  }

  Future<void> _handleDroppedFiles(WidgetRef ref, List<dynamic> xFiles) async {
    final files = <({String fileName, Uint8List bytes})>[];

    for (final xFile in xFiles) {
      try {
        final bytes = await xFile.readAsBytes();
        files.add((fileName: xFile.name as String, bytes: bytes as Uint8List));
      } catch (e) {
        debugPrint('[Mastering] Failed to read dropped file: $e');
      }
    }

    if (files.isNotEmpty) {
      await ref.read(masteringProvider.notifier).addFiles(files);
    }
  }

  Widget _buildStartButton(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    final buttonText = state.isSingleFile
        ? 'Start mastering'
        : 'Master ${state.fileCount} files';

    return HwKey(
      onPressed: state.canStart
          ? () => ref.read(masteringProvider.notifier).startMastering()
          : null,
      icon: Icons.play_arrow,
      label: buttonText,
      style: HwKeyStyle.primary,
      isDefault: true,
    );
  }

  Widget _buildCompletedView(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    final theme = Theme.of(context);

    return RetroWindow(
      title: 'Complete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Annunciator(
              'DONE',
              lit: true,
              color: SlowverbTokens.success,
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Text(
            'Mastering complete',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingXs),
          Text(
            '${state.fileCount} file${state.fileCount > 1 ? 's' : ''} processed successfully',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Faceplate(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final file in state.queuedFiles)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SlowverbTokens.spacingSm,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          color: SlowverbTokens.success,
                          size: 18,
                        ),
                        const SizedBox(width: SlowverbTokens.spacingSm),
                        Expanded(
                          child: Text(
                            _getMasteredFileName(
                              file.fileName,
                              state.selectedFormat,
                            ),
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Wrap(
            spacing: SlowverbTokens.spacingSm,
            runSpacing: SlowverbTokens.spacingSm,
            alignment: WrapAlignment.center,
            children: [
              if (state.zipExportEnabled && state.isBatchMode)
                HwKey(
                  onPressed: () => _downloadZip(state),
                  icon: Icons.archive,
                  label: 'Download ZIP',
                )
              else
                HwKey(
                  onPressed: () => _downloadFiles(state),
                  icon: Icons.download,
                  label: 'Download',
                ),
              HwKey(
                onPressed: () =>
                    ref.read(masteringProvider.notifier).reset(),
                icon: Icons.refresh,
                label: 'Master more files',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    final theme = Theme.of(context);

    return RetroWindow(
      title: 'Error',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Annunciator(
              'FAILED',
              lit: true,
              color: SlowverbTokens.error,
            ),
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Text(
            'Mastering Failed',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingSm),
          Text(
            state.errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SlowverbTokens.spacingLg),
          Center(
            child: HwKey(
              onPressed: () => ref.read(masteringProvider.notifier).reset(),
              icon: Icons.refresh,
              label: 'Try again',
            ),
          ),
        ],
      ),
    );
  }

  String _getMasteredFileName(String original, String format) {
    final baseName = original.replaceAll(RegExp(r'\.[^.]+$'), '');
    return '${baseName}_mastered.$format';
  }

  void _downloadZip(MasteringState state) {
    if (state.zipResult == null) return;
    _download(state.zipResult!, 'slowverb_mastering_batch.zip');
  }

  void _downloadFiles(MasteringState state) {
    if (state.completedResults.isEmpty) return;

    for (var i = 0; i < state.completedResults.length; i++) {
      final bytes = state.completedResults[i];
      final originalName = state.queuedFiles[i].fileName;
      final fileName = _getMasteredFileName(originalName, state.selectedFormat);

      // Small delay between downloads to prevent browser blocking
      Future.delayed(Duration(milliseconds: i * 200), () {
        _download(bytes, fileName);
      });
    }
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
