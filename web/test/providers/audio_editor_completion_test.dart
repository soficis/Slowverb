import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:slowverb_web/providers/audio_editor_provider.dart';
import 'package:slowverb_web/providers/audio_playback_provider.dart';

class _FakePlayer extends Fake implements AudioPlayer {
  // ignore: close_sinks
  final states = StreamController<PlayerState>();
  final calls = <String>[];

  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Duration? get duration => null;
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      calls.add('seek:${position?.inMilliseconds}');
  @override
  Future<void> dispose() async {}
}

void main() {
  test('completion pauses, rewinds and clears isPlaying', () async {
    final player = _FakePlayer();
    final container = ProviderContainer(
      overrides: [audioPlayerProvider.overrideWithValue(player)],
    );
    addTearDown(container.dispose);
    addTearDown(player.states.close);
    final notifier = container.read(audioEditorProvider.notifier);
    notifier.editorState = notifier.editorState.copyWith(isPlaying: true);

    player.states.add(PlayerState(true, ProcessingState.completed));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(audioEditorProvider).isPlaying, isFalse);
    expect(player.calls, ['pause', 'seek:0']);
  });
}
