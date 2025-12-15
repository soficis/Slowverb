import 'dart:convert';

import 'package:idb_shim/idb_browser.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/domain/repositories/preset_repository.dart';
import 'package:web/web.dart' as web;

/// IndexedDB-backed preset repository with localStorage fallback.
class PresetRepositoryWeb implements PresetRepository {
  static const _dbName = 'slowverb_web';
  static const _storeName = 'custom_presets';
  static const _dbVersion = 3; // Incremented from project repo version
  static const _localStorageKey = 'slowverb.custom_presets';

  final IdbFactory? _factory;
  Database? _db;
  bool _useLocalStorage = false;

  PresetRepositoryWeb({IdbFactory? factory})
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

          // Ensure project stores exist (from ProjectRepository)
          if (!db.objectStoreNames.contains('projects')) {
            db.createObjectStore('projects', keyPath: 'id');
          }
          if (!db.objectStoreNames.contains('project_handles')) {
            db.createObjectStore('project_handles');
          }

          // Create custom presets store
          if (!db.objectStoreNames.contains(_storeName)) {
            db.createObjectStore(_storeName, keyPath: 'id');
          }
        },
      );
    } catch (_) {
      // IndexedDB not available; fall back to localStorage
      _useLocalStorage = true;
      _db = null;
    }
  }

  @override
  Future<List<EffectPreset>> getAllCustomPresets() async {
    await initialize();

    if (_useLocalStorage) {
      return _getAllFromLocalStorage();
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final result = await store.getAll();
    await txn.completed;

    final presets = result
        .whereType<Map>()
        .map((json) => _presetFromJson(Map<String, dynamic>.from(json)))
        .toList();

    presets.sort(_sortByUpdatedAt);
    return presets;
  }

  @override
  Future<EffectPreset?> getCustomPreset(String id) async {
    await initialize();

    if (_useLocalStorage) {
      for (final preset in _getAllFromLocalStorage()) {
        if (preset.id == id) return preset;
      }
      return null;
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final json = await store.getObject(id);
    await txn.completed;

    if (json is Map) {
      return _presetFromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  @override
  Future<void> saveCustomPreset(EffectPreset preset) async {
    await initialize();

    final now = DateTime.now();
    final presetJson = _presetToJson(preset, now);

    if (_useLocalStorage) {
      final list = _getAllFromLocalStorage();
      final existingIndex = list.indexWhere((p) => p.id == preset.id);
      if (existingIndex >= 0) {
        list[existingIndex] = preset;
      } else {
        list.add(preset);
      }
      _persistLocalStorage(list);
      return;
    }

    final txn = _db!.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);
    await store.put(presetJson);
    await txn.completed;
  }

  @override
  Future<void> deleteCustomPreset(String id) async {
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
  }

  @override
  Future<bool> hasCustomPreset(String id) async {
    await initialize();

    if (_useLocalStorage) {
      return _getAllFromLocalStorage().any((p) => p.id == id);
    }

    final txn = _db!.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);
    final obj = await store.getObject(id);
    await txn.completed;
    return obj != null;
  }

  Map<String, dynamic> _presetToJson(EffectPreset preset, DateTime timestamp) {
    return {
      'id': preset.id,
      'name': preset.name,
      'description': preset.description,
      'parameters': preset.parameters,
      'createdAt': timestamp.toIso8601String(),
      'updatedAt': timestamp.toIso8601String(),
    };
  }

  EffectPreset _presetFromJson(Map<String, dynamic> json) {
    return EffectPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      parameters: Map<String, double>.from(json['parameters'] as Map),
    );
  }

  List<EffectPreset> _getAllFromLocalStorage() {
    final raw = web.window.localStorage.getItem(_localStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => _presetFromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort(_sortByUpdatedAt);
      }
    } catch (_) {
      // Ignore malformed data
    }
    return [];
  }

  void _persistLocalStorage(List<EffectPreset> presets) {
    final now = DateTime.now();
    final jsonList = presets.map((p) => _presetToJson(p, now)).toList();
    web.window.localStorage.setItem(_localStorageKey, jsonEncode(jsonList));
  }

  int _sortByUpdatedAt(EffectPreset a, EffectPreset b) {
    // Custom presets don't have timestamps in the EffectPreset entity,
    // so we sort alphabetically by name for now
    return a.name.compareTo(b.name);
  }
}
