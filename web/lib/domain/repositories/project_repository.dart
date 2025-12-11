import 'package:slowverb_web/domain/entities/project.dart';

/// Abstract project repository for web.
///
/// Allows swapping storage backends (IndexedDB vs. localStorage fallback)
/// without touching feature code.
abstract class ProjectRepository {
  Future<void> initialize();

  Future<List<Project>> getAllProjects();

  Future<Project?> getProject(String id);

  Future<void> saveProject(Project project, {Object? fileHandle});

  Future<void> deleteProject(String id);

  Future<bool> hasProject(String id);

  /// Retrieve a previously persisted file handle for a project, if any.
  Future<Object?> getProjectHandle(String id);

  /// Check if a project can be reopened with its stored handle.
  Future<bool> canReopenWithHandle(String id);
}
