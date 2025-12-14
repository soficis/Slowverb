import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';

/// Waveform data state
class WaveformState {
  final Float32List? waveform;
  final bool isLoading;
  final String? error;

  const WaveformState({this.waveform, this.isLoading = false, this.error});

  WaveformState copyWith({
    Float32List? waveform,
    bool? isLoading,
    String? error,
  }) {
    return WaveformState(
      waveform: waveform ?? this.waveform,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Waveform data notifier
class WaveformNotifier extends StateNotifier<WaveformState> {
  final Ref _ref;

  WaveformNotifier(this._ref) : super(const WaveformState());

  /// Load waveform for a file ID
  Future<void> loadWaveform(String fileId, {int targetSamples = 1000}) async {
    state = const WaveformState(isLoading: true);

    try {
      final engine = _ref.read(audioEngineProvider);
      final waveform = await engine.getWaveform(
        fileId,
        targetSamples: targetSamples,
      );

      state = WaveformState(waveform: waveform, isLoading: false);
    } catch (e) {
      state = WaveformState(
        isLoading: false,
        error: 'Failed to generate waveform: $e',
      );
    }
  }

  /// Clear waveform
  void clear() {
    state = const WaveformState();
  }
}

/// Provider for waveform data
final waveformProvider = StateNotifierProvider<WaveformNotifier, WaveformState>(
  (ref) {
    return WaveformNotifier(ref);
  },
);
