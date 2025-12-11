import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/data/repositories/project_repository_web.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/repositories/project_repository.dart';

/// Provides a singleton ProjectRepositoryWeb instance.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryWeb();
});

/// Loads all projects, initializing the repository on first use.
final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.read(projectRepositoryProvider);
  await repo.initialize();
  return repo.getAllProjects();
});
