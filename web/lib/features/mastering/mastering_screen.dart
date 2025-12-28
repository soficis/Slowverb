import 'dart:typed_data';
import 'dart:js_interop';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_controls.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_progress.dart';
import 'package:slowverb_web/features/mastering/widgets/mastering_queue.dart';
import 'package:slowverb_web/providers/mastering_provider.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 180,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'PHASELIMITER',
              style: GoogleFonts.orbitron(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Free and local browser-powered AI mastering',
              style: GoogleFonts.rajdhani(
                fontSize: 20,
                color: Colors.white70,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildContent(context, ref, state)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drop zone or file list
              if (state.queuedFiles.isEmpty)
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

              const SizedBox(height: 32),

              // Controls
              if (state.queuedFiles.isNotEmpty) ...[
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
                const SizedBox(height: 32),
                _buildStartButton(context, ref, state),
              ],

              // Error message
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () =>
                            ref.read(masteringProvider.notifier).clearError(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
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
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: _isDragging
                ? Colors.purple.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isDragging
                  ? Colors.purple.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.1),
              width: 4,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  size: 160,
                  color: _isDragging ? Colors.purple : Colors.white54,
                ),
                const SizedBox(height: 40),
                Text(
                  'DROP FILES HERE OR CLICK TO BROWSE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: _isDragging ? Colors.purple : Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Supports: MP3, WAV, FLAC, AAC, OGG',
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
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
        // ignore: avoid_print
        print('[Mastering] Failed to read dropped file: $e');
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
        ? 'START MASTERING'
        : 'MASTER ${state.fileCount} FILES';

    return ElevatedButton(
      onPressed: state.canStart
          ? () => ref.read(masteringProvider.notifier).startMastering()
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        buttonText,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildCompletedView(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'MASTERING COMPLETE',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.fileCount} file${state.fileCount > 1 ? 's' : ''} processed successfully',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 32),

              // File list
              ...state.queuedFiles.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getMasteredFileName(
                            f.fileName,
                            state.selectedFormat,
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.zipExportEnabled && state.isBatchMode)
                    ElevatedButton.icon(
                      onPressed: () => _downloadZip(state),
                      icon: const Icon(Icons.archive),
                      label: const Text('DOWNLOAD ZIP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _downloadFiles(state),
                      icon: const Icon(Icons.download),
                      label: const Text('DOWNLOAD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(masteringProvider.notifier).reset(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Master More Files'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    MasteringState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              'Mastering Failed',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => ref.read(masteringProvider.notifier).reset(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Try Again'),
            ),
          ],
        ),
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
