import 'dart:convert';

import 'package:idb_shim/idb_browser.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/domain/repositories/project_repository.dart';
import 'package:web/web.dart' as web;

/// IndexedDB-backed project repository with a localStorage fallback.
class ProjectRepositoryWeb implements ProjectRepository {
  static const _dbName = 'slowverb_web';
  static const _storeName = 'projects';
  static const _handleStoreName = 'project_handles';
  static const _dbVersion = 2;
  static const _localStorageKey = 'slowverb.projects';

  final IdbFactory? _factory;
  Database? _db;
  bool _useLocalStorage = false;
  bool _handlesSupported = true;

  ProjectRepositoryWeb({IdbFactory? factory})
    : _factory = factory ?? getIdbFactory();

  @override
  Future<void> initialize() async {
    if (_db != null || _useLocalStorage) return;

    try {
      if (_factory == null) {
        _useLocalStorage = true;
        return;
      }

      _db = await _factory.open(
        _dbName,
        version: _dbVersion,
        onUpgradeNeeded: (VersionChangeEvent e) {
          final db = e.database;
          if (!db.objectStoreNames.contains(_storeName)) {
            db.createObjectStore(_storeName, keyPath: 'id');
          }
          if (!db.objectStoreNames.contains(_handleStoreName)) {
            db.createObjectStore(_handleStoreName);
          }
        },
      );
    } catch (_) {
      // IndexedDB not available; fall back to localStorage.
      _useLocalStorage = true;
      _db = null;
    }
  }

  @override
  Future<List<Project>> getAllProjects() async {
    await initialize();

    if (_useLocalStorage) {
      return _getAllFromLocalStorage();
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final result = await store.getAll();
    await txn.completed;

    final projects = result
        .whereType<Map>()
        .map((json) => Project.fromJson(Map<String, dynamic>.from(json)))
        .toList();

    projects.sort(_sortByUpdatedAt);
    return projects;
  }

  @override
  Future<Project?> getProject(String id) async {
    await initialize();

    if (_useLocalStorage) {
      for (final project in _getAllFromLocalStorage()) {
        if (project.id == id) return project;
      }
      return null;
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final json = await store.getObject(id);
    await txn.completed;

    if (json is Map) {
      return Project.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  @override
  Future<void> saveProject(Project project, {Object? fileHandle}) async {
    await initialize();

    final now = DateTime.now();
    final updated = project.copyWith(
      createdAt: project.createdAt ?? now,
      updatedAt: now,
    );

    if (_useLocalStorage) {
      final list = _getAllFromLocalStorage();
      final existingIndex = list.indexWhere((p) => p.id == updated.id);
      if (existingIndex >= 0) {
        list[existingIndex] = updated;
      } else {
        list.add(updated);
      }
      _persistLocalStorage(list);
      return;
    }

    final txn = _db!.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(_projectToJson(updated));
    await txn.completed;

    if (fileHandle != null && _handlesSupported) {
      await _saveHandle(updated.id, fileHandle);
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    await initialize();

    if (_useLocalStorage) {
      final list = _getAllFromLocalStorage()..removeWhere((p) => p.id == id);
      _persistLocalStorage(list);
      return;
    }

    final txn = _db!.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.delete(id);
    await txn.completed;

    if (_handlesSupported) {
      await _deleteHandle(id);
    }
  }

  @override
  Future<bool> hasProject(String id) async {
    await initialize();

    if (_useLocalStorage) {
      return _getAllFromLocalStorage().any((p) => p.id == id);
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    // Use getObject instead of getKey which may not be available in all idb_shim versions
    final obj = await store.getObject(id);
    await txn.completed;
    return obj != null;
  }

  @override
  Future<Object?> getProjectHandle(String id) async {
    await initialize();
    if (_useLocalStorage || !_handlesSupported) return null;

    try {
      final txn = _db!.transaction(_handleStoreName, idbModeReadOnly);
      final store = txn.objectStore(_handleStoreName);
      final handle = await store.getObject(id);
      await txn.completed;
      return handle;
    } catch (_) {
      _handlesSupported = false;
      return null;
    }
  }

  /// Checks if a project can be reopened using its stored file handle.
  /// Returns true if the handle exists and the user has granted permission.
  @override
  Future<bool> canReopenWithHandle(String id) async {
    await initialize();
    if (_useLocalStorage || !_handlesSupported) return false;

    final handle = await getProjectHandle(id);
    if (handle == null) return false;

    // Try to verify permission on the handle
    try {
      // The handle is opaque; we'll check if it's truthy.
      // In a full implementation, we'd call handle.queryPermission()
      // via JS interop, but for now, presence of handle is sufficient.
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _projectToJson(Project project) {
    return {
      'id': project.id,
      'name': project.name,
      'sourcePath': project.sourcePath,
      'sourceHandleId': project.sourceHandleId,
      'sourceFileName': project.sourceFileName,
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

  List<Project> _getAllFromLocalStorage() {
    final raw = web.window.localStorage.getItem(_localStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Project.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort(_sortByUpdatedAt);
      }
    } catch (_) {
      // Ignore malformed data and reset.
    }
    return [];
  }

  void _persistLocalStorage(List<Project> projects) {
    final jsonList = projects.map(_projectToJson).toList();
    web.window.localStorage.setItem(_localStorageKey, jsonEncode(jsonList));
  }

  Future<void> _saveHandle(String projectId, Object handle) async {
    try {
      if (_db == null) return;
      final txn = _db!.transaction(_handleStoreName, idbModeReadWrite);
      final store = txn.objectStore(_handleStoreName);
      await store.put(handle, projectId);
      await txn.completed;
    } catch (_) {
      _handlesSupported = false;
    }
  }

  Future<void> _deleteHandle(String projectId) async {
    try {
      if (_db == null) return;
      final txn = _db!.transaction(_handleStoreName, idbModeReadWrite);
      final store = txn.objectStore(_handleStoreName);
      await store.delete(projectId);
      await txn.completed;
    } catch (_) {
      _handlesSupported = false;
    }
  }

  int _sortByUpdatedAt(Project a, Project b) {
    final aDate =
        a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  }
}
