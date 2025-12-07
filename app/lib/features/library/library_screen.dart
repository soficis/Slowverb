import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/data/providers/project_providers.dart';
import 'package:slowverb/domain/entities/project.dart';
import 'package:slowverb/features/editor/editor_provider.dart';
import 'package:slowverb/features/library/widgets/project_card.dart';

/// Home screen showing the project library
///
/// Displays saved projects and provides access to import new tracks.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    // Load saved projects on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectListProvider.notifier).loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedProjects = ref.watch(projectListProvider);
    final editorState = ref.watch(editorProvider);
    final currentProject = editorState.currentProject;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildHeader(context),
              if (currentProject != null)
                _buildCurrentSession(context, currentProject),
              if (savedProjects.isNotEmpty)
                _buildSavedProjectsSection(
                  context,
                  savedProjects,
                  currentProject?.id,
                ),
              if (currentProject == null && savedProjects.isEmpty)
                _buildEmptyState(context),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildImportButton(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SlowverbColors.accentGradient,
                  ),
                  child: const Icon(
                    Icons.slow_motion_video,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Slowverb',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your Projects',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSession(BuildContext context, Project project) {
    final duration = Duration(milliseconds: project.durationMs);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Session',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: SlowverbColors.neonCyan,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _saveCurrentProject(project),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: TextButton.styleFrom(
                    foregroundColor: SlowverbColors.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProjectCard(
              title: project.name,
              presetName: _getPresetName(project.presetId),
              duration: duration,
              lastModified: project.updatedAt ?? DateTime.now(),
              onTap: () => context.go(RoutePaths.editorWithId(project.id)),
              isCurrentSession: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedProjectsSection(
    BuildContext context,
    List<Project> projects,
    String? currentId,
  ) {
    // Filter out current session from saved projects
    final filteredProjects = projects.where((p) => p.id != currentId).toList();

    if (filteredProjects.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Projects',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: SlowverbColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            ...filteredProjects.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: Key(project.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: SlowverbColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) =>
                      _confirmDelete(context, project),
                  onDismissed: (direction) => _deleteProject(project.id),
                  child: ProjectCard(
                    title: project.name,
                    presetName: _getPresetName(project.presetId),
                    duration: Duration(milliseconds: project.durationMs),
                    lastModified:
                        project.updatedAt ??
                        project.createdAt ??
                        DateTime.now(),
                    onTap: () => _loadProject(context, project),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SlowverbColors.surface,
                  border: Border.all(
                    color: SlowverbColors.surfaceVariant,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.library_music_outlined,
                  size: 48,
                  color: SlowverbColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No projects yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Import a track to create your first\nslowed + reverb edit',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SlowverbColors.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _handleImportTrack(context),
                icon: const Icon(Icons.add),
                label: const Text('Import Track'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _handleImportTrack(context),
      icon: const Icon(Icons.add),
      label: const Text('Import'),
    );
  }

  String _getPresetName(String presetId) {
    switch (presetId) {
      case 'slowed_reverb':
        return 'Slowed + Reverb';
      case 'vaporwave_chill':
        return 'Vaporwave Chill';
      case 'nightcore':
        return 'Nightcore';
      case 'echo_slow':
        return 'Echo Slow';
      case 'manual':
        return 'Manual';
      default:
        return 'Custom';
    }
  }

  Future<void> _handleImportTrack(BuildContext context) async {
    final notifier = ref.read(editorProvider.notifier);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: SlowverbColors.hotPink),
      ),
    );

    final success = await notifier.importAudioFile();

    // Hide loading indicator
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (success && context.mounted) {
      // Navigate to effect selection
      context.go(RoutePaths.effects);
    } else if (context.mounted) {
      final state = ref.read(editorProvider);
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: SlowverbColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentProject(Project project) async {
    await ref.read(projectListProvider.notifier).saveProject(project);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project saved'),
          backgroundColor: SlowverbColors.success,
        ),
      );
    }
  }

  Future<void> _loadProject(BuildContext context, Project project) async {
    // TODO: Implement loadProject method in EditorNotifier
    // For now, show a message that this feature is coming
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading saved projects coming soon...'),
        backgroundColor: SlowverbColors.electricBlue,
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Project project) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: SlowverbColors.surface,
            title: const Text('Delete Project?'),
            content: Text('Are you sure you want to delete "${project.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: SlowverbColors.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteProject(String id) {
    ref.read(projectListProvider.notifier).deleteProject(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Project deleted'),
        backgroundColor: SlowverbColors.onSurfaceMuted,
      ),
    );
  }
}
