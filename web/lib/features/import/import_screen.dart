import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/router.dart';
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
    try {
      // Try File System Access API first for handle reuse.
      final fsaFile = await FileSystemAccess.pickAudioFile();
      if (fsaFile != null) {
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          setState(() => _isLoading = false);
          context.push(
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to read file data'),
                backgroundColor: SlowverbColors.error,
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

          context.push(
            AppRoutes.editor,
            extra: EditorScreenArgs(fileData: fileData),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: SlowverbColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Title
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          SlowverbColors.primaryGradient.createShader(bounds),
                      child: Text(
                        'SLOWVERB',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w200,
                              letterSpacing: 8.0,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Slowed + Reverb Editor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SlowverbColors.textSecondary,
                        letterSpacing: 2.0,
                      ),
                    ),

                    const SizedBox(height: 64),

                    // Drop zone
                    MouseRegion(
                      onEnter: (_) => setState(() => _isHovering = true),
                      onExit: (_) => setState(() => _isHovering = false),
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickFile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 300,
                          decoration: BoxDecoration(
                            color: _isHovering
                                ? SlowverbColors.surfaceVariant
                                : SlowverbColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isHovering
                                  ? SlowverbColors.primaryPurple
                                  : SlowverbColors.backgroundLight,
                              width: 2,
                            ),
                            boxShadow: _isHovering
                                ? [
                                    BoxShadow(
                                      color: SlowverbColors.primaryPurple
                                          .withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: SlowverbColors.primaryPurple,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.audio_file_outlined,
                                      size: 64,
                                      color: _isHovering
                                          ? SlowverbColors.primaryPurple
                                          : SlowverbColors.textSecondary,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Drop audio file here',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: _isHovering
                                                ? SlowverbColors.textPrimary
                                                : SlowverbColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'or click to browse',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 32),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: _supportedExtensions
                                          .map(
                                            (ext) => Chip(
                                              label: Text(
                                                ext.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              backgroundColor: SlowverbColors
                                                  .backgroundLight,
                                              side: BorderSide.none,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push(AppRoutes.library),
                          icon: const Icon(Icons.library_music),
                          label: const Text('Open Library'),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () => context.push(AppRoutes.batchExport),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Batch Export'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Privacy notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SlowverbColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: SlowverbColors.success,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All processing happens locally in your browser. Your audio never leaves your device.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: SlowverbColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

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
        ),
      ),
    );
  }
}
