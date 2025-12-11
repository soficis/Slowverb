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
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:slowverb/domain/entities/project.dart';

/// Repository for persisting projects to local storage using Hive
class ProjectRepository {
  static const String _boxName = 'projects';
  late Box<Map> _box;

  /// Initialize the repository
  Future<void> initialize() async {
    // Hive is initialized in main.dart; re-calling init here crashes on Android.
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<Map>(_boxName);
      return;
    }

    try {
      _box = await Hive.openBox<Map>(_boxName);
    } catch (e, st) {
      // If the box is corrupted or unreadable, fall back to a fresh box so the
      // app can still boot instead of showing a white screen.
      debugPrint(
        'Failed to open Hive box "$_boxName": $e\n$st\n'
        'Recreating projects box (existing entries may be ignored).',
      );
      // Keep the same box name so future launches continue to use the clean box.
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<Map>(_boxName);
    }
  }

  /// Get all projects sorted by last updated
  List<Project> getAllProjects() {
    final projects = <Project>[];

    for (final raw in _box.values) {
      try {
        projects.add(_projectFromJson(Map<String, dynamic>.from(raw)));
      } catch (e, st) {
        // Skip corrupt or legacy entries instead of crashing the app.
        debugPrint('Skipping corrupt project entry: $e\n$st');
      }
    }

    projects.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate); // Most recent first
    });

    return projects;
  }

  /// Get a project by ID
  Project? getProject(String id) {
    final json = _box.get(id);
    if (json == null) return null;
    try {
      return _projectFromJson(Map<String, dynamic>.from(json));
    } catch (e, st) {
      debugPrint('Corrupt project $id skipped: $e\n$st');
      return null;
    }
  }

  /// Save a project (create or update)
  Future<void> saveProject(Project project) async {
    final updatedProject = project.copyWith(updatedAt: DateTime.now());
    await _box.put(project.id, _projectToJson(updatedProject));
  }

  /// Delete a project by ID
  Future<void> deleteProject(String id) async {
    await _box.delete(id);
  }

  /// Check if a project exists
  bool hasProject(String id) {
    return _box.containsKey(id);
  }

  /// Get the number of saved projects
  int get projectCount => _box.length;

  /// Convert Project to JSON for storage
  Map<String, dynamic> _projectToJson(Project project) {
    return {
      'id': project.id,
      'name': project.name,
      'sourcePath': project.sourcePath,
      'sourceTitle': project.sourceTitle,
      'sourceArtist': project.sourceArtist,
      'durationMs': project.durationMs,
      'presetId': project.presetId,
      'parameters': project.parameters,
      'createdAt': project.createdAt?.toIso8601String(),
      'updatedAt': project.updatedAt?.toIso8601String(),
      'lastExportPath': project.lastExportPath,
      'lastExportFormat': project.lastExportFormat,
      'lastExportBitrateKbps': project.lastExportBitrateKbps,
      'lastExportDate': project.lastExportDate?.toIso8601String(),
    };
  }

  /// Convert JSON to Project
  Project _projectFromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      sourcePath: json['sourcePath'] as String,
      sourceTitle: json['sourceTitle'] as String?,
      sourceArtist: json['sourceArtist'] as String?,
      durationMs: json['durationMs'] as int,
      presetId: json['presetId'] as String,
      parameters: Map<String, double>.from(json['parameters'] ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      lastExportPath: json['lastExportPath'] as String?,
      lastExportFormat: json['lastExportFormat'] as String?,
      lastExportBitrateKbps: json['lastExportBitrateKbps'] as int?,
      lastExportDate: json['lastExportDate'] != null
          ? DateTime.parse(json['lastExportDate'] as String)
          : null,
    );
  }
}
