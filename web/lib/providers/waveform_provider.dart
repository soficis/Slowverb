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
