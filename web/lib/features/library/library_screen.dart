import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/app/retro/retro_widgets.dart';
import 'package:slowverb_web/app/router.dart';
import 'package:slowverb_web/app/slowverb_design_tokens.dart';
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
    final padding = EdgeInsets.all(
      MediaQuery.sizeOf(context).width < 600
          ? SlowverbTokens.spacingMd
          : SlowverbTokens.spacingLg,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.go(AppRoutes.import_),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(projectsProvider),
          ),
        ],
      ),
      body: RetroDesktop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: projectsAsync.when(
                loading: () => Padding(
                  padding: padding,
                  child: const RetroWindow(
                    title: 'Library',
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: SlowverbTokens.vfdCyan,
                        ),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: padding,
                  child: RetroWindow(
                    title: 'Library',
                    child: _LibraryMessage(
                      icon: Icons.error_outline,
                      title: 'Failed to load library',
                      message: e.toString(),
                    ),
                  ),
                ),
                data: (projects) {
                  if (projects.isEmpty) {
                    return Padding(
                      padding: padding,
                      child: const RetroWindow(
                        title: 'Library',
                        child: _LibraryMessage(
                          icon: Icons.library_music_outlined,
                          title: 'No projects yet',
                          message:
                              'Import a file to create your first project entry.',
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: padding,
                    children: [
                      RetroWindow(
                        title: 'Library',
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < projects.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _ProjectCard(
                                project: projects[i],
                                onOpen: () =>
                                    _openProject(context, ref, projects[i]),
                                onDelete: () async {
                                  final repo = ref.read(
                                    projectRepositoryProvider,
                                  );
                                  await repo.deleteProject(projects[i].id);
                                  ref.invalidate(projectsProvider);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
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
          title: const Row(
            children: [
              Icon(Icons.link_off, color: SlowverbTokens.warning),
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
                style: Theme.of(context).textTheme.bodySmall,
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
            backgroundColor: SlowverbTokens.error,
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
          backgroundColor: SlowverbTokens.error,
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SlowverbTokens.spacingMd,
        vertical: SlowverbTokens.spacingMd,
      ),
      child: Row(
        children: [
          // Album art placeholder.
          const Faceplate(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.music_note,
                color: SlowverbTokens.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: SlowverbTokens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Track name
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // File name
                Text(
                  project.sourceFileName ?? 'Unknown file',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Preset, duration and export format readouts
                Wrap(
                  spacing: SlowverbTokens.spacingSm,
                  runSpacing: SlowverbTokens.spacingXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    VfdText(
                      presetName,
                      size: 12,
                      color: SlowverbTokens.sunsetPink,
                    ),
                    if (durationLabel != null) VfdText(durationLabel, size: 12),
                    if (project.lastExportFormat != null)
                      VfdText(
                        project.lastExportFormat!.toUpperCase(),
                        size: 12,
                        color: SlowverbTokens.success,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Timestamps
                Wrap(
                  spacing: SlowverbTokens.spacingSm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (project.updatedAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.update,
                            size: 12,
                            color: SlowverbTokens.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeTime(project.updatedAt!),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    if (project.lastExportDate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.download_done,
                            size: 12,
                            color: SlowverbTokens.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Exported ${_formatRelativeTime(project.lastExportDate!)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SlowverbTokens.spacingMd),
          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HwKey(
                onPressed: onOpen,
                icon: Icons.play_arrow,
                label: 'Open',
                style: HwKeyStyle.primary,
              ),
              const SizedBox(height: 6),
              HwKey(
                onPressed: onDelete,
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                style: HwKeyStyle.danger,
                size: 36,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: SlowverbTokens.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
