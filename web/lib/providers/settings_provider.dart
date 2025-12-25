import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

/// Experimental features configuration
class ExperimentalFeatures {
  final bool streamingAudioEnabled;

  const ExperimentalFeatures({this.streamingAudioEnabled = false});

  ExperimentalFeatures copyWith({bool? streamingAudioEnabled}) {
    return ExperimentalFeatures(
      streamingAudioEnabled:
          streamingAudioEnabled ?? this.streamingAudioEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'streamingAudioEnabled': streamingAudioEnabled,
  };

  factory ExperimentalFeatures.fromJson(Map<String, dynamic> json) {
    return ExperimentalFeatures(
      streamingAudioEnabled: json['streamingAudioEnabled'] as bool? ?? false,
    );
  }
}

/// Notifier for managing experimental features with persistence
class ExperimentalFeaturesNotifier extends StateNotifier<ExperimentalFeatures> {
  static const _storageKey = 'slowverb.experimental_features';

  ExperimentalFeaturesNotifier() : super(const ExperimentalFeatures()) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final stored = web.window.localStorage.getItem(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        state = ExperimentalFeatures.fromJson(json);
      }
    } catch (_) {
      // Ignore malformed data
    }
  }

  void _saveToStorage() {
    web.window.localStorage.setItem(_storageKey, jsonEncode(state.toJson()));
  }

  void setStreamingAudioEnabled(bool enabled) {
    state = state.copyWith(streamingAudioEnabled: enabled);
    _saveToStorage();
  }

  void reset() {
    state = const ExperimentalFeatures();
    _saveToStorage();
  }
}

/// Provider for experimental features
final experimentalFeaturesProvider =
    StateNotifierProvider<ExperimentalFeaturesNotifier, ExperimentalFeatures>(
      (ref) => ExperimentalFeaturesNotifier(),
    );

/// Mastering settings configuration
class MasteringSettings {
  final bool masteringEnabled;
  final bool phaselimiterEnabled;
  final int mode;

  const MasteringSettings({
    this.masteringEnabled = false,
    this.phaselimiterEnabled = false,
    this.mode = 5, // Level 5 (HNSW Pro)
  });

  MasteringSettings copyWith({
    bool? masteringEnabled,
    bool? phaselimiterEnabled,
    int? mode,
  }) {
    return MasteringSettings(
      masteringEnabled: masteringEnabled ?? this.masteringEnabled,
      phaselimiterEnabled: phaselimiterEnabled ?? this.phaselimiterEnabled,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() => {
    'masteringEnabled': masteringEnabled,
    'phaselimiterEnabled': phaselimiterEnabled,
    'mode': mode,
  };

  factory MasteringSettings.fromJson(Map<String, dynamic> json) {
    return MasteringSettings(
      masteringEnabled: json['masteringEnabled'] as bool? ?? false,
      phaselimiterEnabled: json['phaselimiterEnabled'] as bool? ?? false,
      mode: json['mode'] as int? ?? 5, // Level 5 (HNSW Pro)
    );
  }
}

/// Notifier for managing mastering settings with persistence
class MasteringSettingsNotifier extends StateNotifier<MasteringSettings> {
  static const _storageKey = 'slowverb.mastering_settings';

  MasteringSettingsNotifier() : super(const MasteringSettings()) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final stored = web.window.localStorage.getItem(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        state = MasteringSettings.fromJson(json);
      }
    } catch (_) {
      // Ignore malformed data
    }
  }

  void _saveToStorage() {
    web.window.localStorage.setItem(_storageKey, jsonEncode(state.toJson()));
  }

  void setMasteringEnabled(bool enabled) {
    state = state.copyWith(masteringEnabled: enabled);
    _saveToStorage();
  }

  void setPhaselimiterEnabled(bool enabled) {
    state = state.copyWith(phaselimiterEnabled: enabled);
    _saveToStorage();
  }

  void setMode(int mode) {
    state = state.copyWith(mode: mode);
    _saveToStorage();
  }

  void reset() {
    state = const MasteringSettings();
    _saveToStorage();
  }
}

/// Provider for mastering settings
final masteringSettingsProvider =
    StateNotifierProvider<MasteringSettingsNotifier, MasteringSettings>(
      (ref) => MasteringSettingsNotifier(),
    );
