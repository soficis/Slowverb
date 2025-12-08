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
import 'package:slowverb_web/engine/wasm_audio_engine.dart';

/// Provider for the audio engine singleton
final audioEngineProvider = Provider<WasmAudioEngine>((ref) {
  final engine = WasmAudioEngine();

  // Clean up engine when provider is disposed
  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

/// Provider for engine initialization
///
/// Watch this to ensure engine is ready before using
final engineInitProvider = FutureProvider<void>((ref) async {
  final engine = ref.watch(audioEngineProvider);

  if (!engine.isReady) {
    await engine.initialize();
  }
});

/// Provider for engine ready state
final engineReadyProvider = Provider<bool>((ref) {
  final initState = ref.watch(engineInitProvider);
  return initState.when(
    data: (_) => true,
    loading: () => false,
    error: (_, __) => false,
  );
});
