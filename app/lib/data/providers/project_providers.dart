/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:slowverb/data/repositories/project_repository.dart';
import 'package:slowverb/domain/entities/project.dart';

/// Provider for the project repository singleton
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  throw UnimplementedError('projectRepositoryProvider must be overridden');
});

/// Provider for the list of saved projects
final projectListProvider =
    NotifierProvider<ProjectListNotifier, List<Project>>(
      ProjectListNotifier.new,
    );

/// Notifier for managing the project list
class ProjectListNotifier extends Notifier<List<Project>> {
  late ProjectRepository _repository;

  @override
  List<Project> build() {
    _repository = ref.watch(projectRepositoryProvider);
    return [];
  }

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
