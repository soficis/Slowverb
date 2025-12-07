import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/data/repositories/project_repository.dart';
import 'package:slowverb/domain/entities/project.dart';

/// Provider for the project repository singleton
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

/// Provider for the list of saved projects
final projectListProvider =
    StateNotifierProvider<ProjectListNotifier, List<Project>>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      return ProjectListNotifier(repository);
    });

/// Notifier for managing the project list
class ProjectListNotifier extends StateNotifier<List<Project>> {
  final ProjectRepository _repository;

  ProjectListNotifier(this._repository) : super([]);

  /// Load all projects from storage
  void loadProjects() {
    state = _repository.getAllProjects();
  }

  /// Add or update a project
  Future<void> saveProject(Project project) async {
    await _repository.saveProject(project);
    loadProjects();
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    await _repository.deleteProject(id);
    loadProjects();
  }

  /// Get a specific project
  Project? getProject(String id) {
    return _repository.getProject(id);
  }
}
