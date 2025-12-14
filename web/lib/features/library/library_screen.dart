import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/colors.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/providers/project_repository_provider.dart';
import 'package:slowverb_web/utils/file_system_access.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.import_),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(projectsProvider),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: projectsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: SlowverbColors.primaryPurple,
                ),
              ),
              error: (e, _) => _LibraryMessage(
                icon: Icons.error_outline,
                title: 'Failed to load library',
                message: e.toString(),
              ),
              data: (projects) {
                if (projects.isEmpty) {
                  return const _LibraryMessage(
                    icon: Icons.library_music_outlined,
                    title: 'No projects yet',
                    message:
                        'Import a file to create your first project entry.',
                  );
                }

                return ListView.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _ProjectCard(
                      project: project,
                      onOpen: () => _openProject(context, ref, project),
                      onDelete: () async {
                        final repo = ref.read(projectRepositoryProvider);
                        await repo.deleteProject(project.id);
                        ref.invalidate(projectsProvider);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    try {
      final repo = ref.read(projectRepositoryProvider);
      final handle = await repo.getProjectHandle(project.id);

      if (handle != null) {
        final fileData = await FileSystemAccess.loadFromHandle(handle);
        if (fileData != null) {
          if (!context.mounted) return;
          context.push(
            AppRoutes.editor,
            extra: EditorScreenArgs(fileData: fileData, project: project),
          );
          return;
        }
      }

      // Handle unavailable - show relink dialog
      if (!context.mounted) return;
      final shouldRelink = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SlowverbColors.surface,
          title: const Row(
            children: [
              Icon(Icons.link_off, color: SlowverbColors.warning),
              SizedBox(width: 12),
              Text('File Access Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The original audio file for "${project.name}" is no longer accessible.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Please select the file again to continue editing this project.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SlowverbColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.folder_open),
              label: const Text('Select File'),
            ),
          ],
        ),
      );

      if (shouldRelink != true) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to read file data'),
            backgroundColor: SlowverbColors.error,
          ),
        );
        return;
      }

      final fileData = AudioFileData(filename: file.name, bytes: file.bytes!);
      if (!context.mounted) return;
      context.push(
        AppRoutes.editor,
        extra: EditorScreenArgs(fileData: fileData, project: project),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening project: $e'),
          backgroundColor: SlowverbColors.error,
        ),
      );
    }
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final durationLabel = project.durationMs > 0
        ? _formatDuration(Duration(milliseconds: project.durationMs))
        : null;
    final preset = Presets.getById(project.presetId);
    final presetName = preset?.name ?? project.presetId;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SlowverbColors.surface.withValues(alpha: 0.9),
            SlowverbColors.surfaceVariant.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(
          color: SlowverbColors.primaryPurple.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: SlowverbColors.primaryPurple.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Album art placeholder with gradient
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SlowverbColors.primaryPurple,
                    SlowverbColors.accentPink,
                  ],
                ),
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Track name
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: SlowverbColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // File name
                  Text(
                    project.sourceFileName ?? 'Unknown file',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SlowverbColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Preset chip
                      _buildChip(presetName, SlowverbColors.primaryPurple),
                      // Duration chip
                      if (durationLabel != null)
                        _buildChip(durationLabel, SlowverbColors.accentCyan),
                      // Export format chip
                      if (project.lastExportFormat != null)
                        _buildChip(
                          project.lastExportFormat!.toUpperCase(),
                          SlowverbColors.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Timestamps row
                  Row(
                    children: [
                      if (project.updatedAt != null) ...[
                        Icon(
                          Icons.update,
                          size: 12,
                          color: SlowverbColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatRelativeTime(project.updatedAt!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: SlowverbColors.textHint,
                                fontSize: 11,
                              ),
                        ),
                      ],
                      if (project.lastExportDate != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.download_done,
                          size: 12,
                          color: SlowverbColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Exported ${_formatRelativeTime(project.lastExportDate!)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: SlowverbColors.textHint,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Open button with gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        SlowverbColors.primaryPurple,
                        SlowverbColors.accentPink,
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpen,
                      borderRadius: BorderRadius.circular(24),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Open',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Delete button
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: SlowverbColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _LibraryMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: SlowverbColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: SlowverbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SlowverbColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
