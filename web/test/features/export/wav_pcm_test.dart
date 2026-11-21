import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/features/export/wav_pcm.dart';

Uint8List _wav({
  required int channels,
  required List<int> samples16,
  int sampleRate = 44100,
}) {
  final dataLen = samples16.length * 2;
  final b = ByteData(44 + dataLen);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * channels * 2, Endian.little);
  b.setUint16(32, channels * 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples16.length; i++) {
    b.setInt16(44 + i * 2, samples16[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  test('decodes 16-bit stereo', () {
    final pcm = decodeWavToStereo(
      _wav(channels: 2, samples16: [16384, -16384, 0, 32767]),
    );
    expect(pcm.sampleRate, 44100);
    expect(pcm.left.length, 2);
    expect(pcm.left[0], closeTo(0.5, 1e-6));
    expect(pcm.right[0], closeTo(-0.5, 1e-6));
    expect(pcm.right[1], closeTo(1.0, 1e-3));
  });

  test('duplicates mono to both channels', () {
    final pcm = decodeWavToStereo(_wav(channels: 1, samples16: [8192, -8192]));
    expect(pcm.left, pcm.right);
    expect(pcm.left.length, 2);
  });

  test('rejects non-WAV input', () {
    expect(
      () => decodeWavToStereo(Uint8List.fromList(List.filled(64, 7))),
      throwsFormatException,
    );
  });
}
