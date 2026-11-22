import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:slowverb_web/features/visualizer/analysis_stream_controller.dart';
import 'package:slowverb_web/providers/audio_engine_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';

/// Analysis frames for the current preview, sampled at the player position.
final analysisStreamProvider = Provider<Stream<AudioAnalysisFrame>>((ref) {
  final player = ref.watch(audioPlayerProvider);
  final engine = ref.watch(audioEngineProvider);
  final controller = AnalysisStreamController(
    track: () => engine.previewAnalysis,
    position: () => player.position,
    // just_audio keeps `playing` true after completion; treat that as stopped.
    playing: player.playerStateStream.map(
      (s) => s.playing && s.processingState != ProcessingState.completed,
    ),
  );
  ref.onDispose(controller.dispose);
  return controller.stream;
});
