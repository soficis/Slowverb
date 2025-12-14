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
