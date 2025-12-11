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
