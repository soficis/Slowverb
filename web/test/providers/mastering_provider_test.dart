import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/entities/mastering_settings.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/providers/mastering_provider.dart';

AudioMetadata _metadata(String format) {
  return AudioMetadata(
    fileId: 'id-$format',
    filename: 'track.$format',
    duration: const Duration(seconds: 10),
    sampleRate: 44100,
    channels: 2,
    format: format,
  );
}

MasteringQueueFile _file(String id, String format) {
  return MasteringQueueFile(
    fileId: id,
    fileName: 'file-$id.$format',
    bytes: Uint8List(16),
    metadata: _metadata(format),
  );
}

void main() {
  group('MasteringState', () {
    test('enables FLAC only for all-lossless queues', () {
      final losslessState = MasteringState(queuedFiles: [_file('1', 'wav'), _file('2', 'flac')]);
      final mixedState = MasteringState(queuedFiles: [_file('1', 'wav'), _file('2', 'mp3')]);

      expect(losslessState.isFlacEnabled, isTrue);
      expect(mixedState.isFlacEnabled, isFalse);
    });

    test('canStart requires queued files and idle status', () {
      const emptyState = MasteringState();
      final readyState = MasteringState(queuedFiles: [_file('1', 'wav')]);
      final runningState = readyState.copyWith(status: MasteringStatus.mastering);

      expect(emptyState.canStart, isFalse);
      expect(readyState.canStart, isTrue);
      expect(runningState.canStart, isFalse);
    });

    test('copyWith clears error and zip data when requested', () {
      final state = MasteringState(
        queuedFiles: [_file('1', 'wav')],
        errorMessage: 'boom',
        zipResult: Uint8List.fromList([1, 2, 3]),
      );

      final cleared = state.copyWith(clearError: true, clearZip: true);
      expect(cleared.errorMessage, isNull);
      expect(cleared.zipResult, isNull);
    });
  });
}
