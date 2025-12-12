import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';

void main() {
  group('AudioMetadata FLAC Gating', () {
    test('isLossless returns true for WAV', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.wav',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'wav',
      );
      expect(metadata.isLossless, isTrue);
    });

    test('isLossless returns true for FLAC', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.flac',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'flac',
      );
      expect(metadata.isLossless, isTrue);
    });

    test('isLossless returns true for AIFF', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.aiff',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'aiff',
      );
      expect(metadata.isLossless, isTrue);
    });

    test('isLossless returns false for MP3', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.mp3',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'mp3',
      );
      expect(metadata.isLossless, isFalse);
    });

    test('isLossless returns false for AAC', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.aac',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'aac',
      );
      expect(metadata.isLossless, isFalse);
    });

    test('isLossless is case insensitive', () {
      const metadata = AudioMetadata(
        fileId: '1',
        filename: 'test.WAV',
        duration: Duration.zero,
        sampleRate: 44100,
        channels: 2,
        format: 'WAV',
      );
      expect(metadata.isLossless, isTrue);
    });
  });
}
