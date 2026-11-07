import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/utils/file_system_access.dart';

/// Import screen for selecting audio files
///
/// Supports MP3, WAV, AAC, M4A, OGG, and FLAC formats
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isHovering = false;
  bool _isLoading = false;

  static const _supportedExtensions = [
    'mp3',
    'wav',
    'aac',
    'm4a',
    'ogg',
    'flac',
  ];

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      // Try File System Access API first for handle reuse.
      final fsaFile = await FileSystemAccess.pickAudioFile();
      if (fsaFile != null) {
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          setState(() => _isLoading = false);
          router.push(
            AppRoutes.editor,
            extra: EditorScreenArgs(fileData: fsaFile),
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
        withData: true, // Load file data for web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Ensure we have file bytes
        if (file.bytes == null) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Failed to read file data'),
                backgroundColor: SlowverbTokens.error,
              ),
            );
          }
          return;
        }

        setState(() => _isLoading = true);

        // Small delay to show loading state
        await Future.delayed(const Duration(milliseconds: 300));

        // Navigate to editor with file data
        if (mounted) {
          setState(() => _isLoading = false);

          // Pass AudioFileData object
          final fileData = AudioFileData(
            filename: file.name,
            bytes: file.bytes!,
          );

          router.push(
            AppRoutes.editor,
            extra: EditorScreenArgs(fileData: fileData),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: SlowverbTokens.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final padding = EdgeInsets.all(
      narrow ? SlowverbTokens.spacingMd : SlowverbTokens.spacingXl,
    );
    final formats = _supportedExtensions
        .map((ext) => ext.toUpperCase())
        .join(' · ');

    return Scaffold(
      body: RetroDesktop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - padding.vertical,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Wordmark and subtitle
                          SlowverbWordmark(size: narrow ? 30 : 44),
                          const SizedBox(height: SlowverbTokens.spacingSm),
                          Text(
                            'Slowed + Reverb Editor',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),

                          SizedBox(
                            height: narrow
                                ? SlowverbTokens.spacingLg
                                : SlowverbTokens.spacing2Xl,
                          ),

                          // Drop zone
                          RetroWindow(
                            title: 'Open a song',
                            child: DropTarget(
                              onDragDone: (details) async {
                                if (details.files.isEmpty) return;
                                final file = details.files.first;
                                final messenger = ScaffoldMessenger.of(context);
                                final router = GoRouter.of(context);

                                // Check extension
                                final ext = file.name
                                    .split('.')
                                    .last
                                    .toLowerCase();
                                if (!_supportedExtensions.contains(ext)) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Unsupported file format: .$ext',
                                        ),
                                        backgroundColor: SlowverbTokens.error,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                setState(() => _isLoading = true);

                                try {
                                  final bytes = await file.readAsBytes();
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                    final fileData = AudioFileData(
                                      filename: file.name,
                                      bytes: bytes,
                                    );

                                    router.push(
                                      AppRoutes.editor,
                                      extra: EditorScreenArgs(
                                        fileData: fileData,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error reading file: $e'),
                                        backgroundColor: SlowverbTokens.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              onDragEntered: (_) =>
                                  setState(() => _isHovering = true),
                              onDragExited: (_) =>
                                  setState(() => _isHovering = false),
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _isHovering = true),
                                onExit: (_) =>
                                    setState(() => _isHovering = false),
                                child: InkWell(
                                  onTap: _isLoading ? null : _pickFile,
                                  borderRadius: BorderRadius.circular(
                                    SlowverbTokens.radiusSm,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        SlowverbTokens.radiusSm,
                                      ),
                                      border: Border.all(
                                        color: _isHovering
                                            ? SlowverbTokens.vfdCyan
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: VfdPanel(
                                      child: SizedBox(
                                        height: 220,
                                        width: double.infinity,
                                        child: _isLoading
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: SlowverbTokens
                                                          .vfdCyan,
                                                    ),
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.audio_file_outlined,
                                                    size: 56,
                                                    color: _isHovering
                                                        ? SlowverbTokens.vfdCyan
                                                        : SlowverbTokens
                                                              .textSecondary,
                                                  ),
                                                  const SizedBox(
                                                    height: SlowverbTokens
                                                        .spacingMd,
                                                  ),
                                                  const VfdText(
                                                    'Drop audio file here',
                                                    size: 18,
                                                  ),
                                                  const SizedBox(
                                                    height: SlowverbTokens
                                                        .spacingSm,
                                                  ),
                                                  Text(
                                                    'or click to browse',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                  const SizedBox(
                                                    height: SlowverbTokens
                                                        .spacingLg,
                                                  ),
                                                  VfdText(formats, size: 12),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: SlowverbTokens.spacingLg),

                          // Secondary destinations
                          Wrap(
                            spacing: SlowverbTokens.spacingMd,
                            runSpacing: SlowverbTokens.spacingSm,
                            alignment: WrapAlignment.center,
                            children: [
                              HwKey(
                                onPressed: () =>
                                    context.push(AppRoutes.library),
                                icon: Icons.library_music,
                                label: 'LIBRARY',
                              ),
                              HwKey(
                                onPressed: () =>
                                    context.push(AppRoutes.batchExport),
                                icon: Icons.folder_open,
                                label: 'BATCH',
                              ),
                              HwKey(
                                onPressed: () =>
                                    context.push(AppRoutes.mastering),
                                icon: Icons.equalizer,
                                label: 'MASTERING',
                              ),
                            ],
                          ),

                          const SizedBox(height: SlowverbTokens.spacingLg),

                          // Privacy notice
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: SlowverbTokens.success,
                              ),
                              const SizedBox(width: SlowverbTokens.spacingSm),
                              Flexible(
                                child: Text(
                                  'All processing happens locally in your browser. Your audio never leaves your device.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: SlowverbTokens.spacingMd),

                          // About link
                          TextButton(
                            onPressed: () => context.push(AppRoutes.about),
                            child: const Text('About Slowverb'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
