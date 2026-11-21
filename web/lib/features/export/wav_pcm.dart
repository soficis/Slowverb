import 'dart:typed_data';

/// Stereo float PCM decoded from a WAV file.
typedef WavPcm = ({Float32List left, Float32List right, int sampleRate});

/// Decodes a RIFF/WAVE file (16/24-bit PCM or 32-bit float, mono or stereo).
///
/// Mono is duplicated to both channels. Throws [FormatException] on anything
/// else, so a bad render fails loudly instead of producing a silent video.
WavPcm decodeWavToStereo(Uint8List bytes) {
  if (bytes.length < 12 ||
      _tag(bytes, 0) != 'RIFF' ||
      _tag(bytes, 8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }
  final view = ByteData.sublistView(bytes);

  int? format;
  int channels = 0;
  int sampleRate = 0;
  int bits = 0;
  int dataStart = -1;
  int dataLength = 0;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      format = view.getUint16(body, Endian.little);
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 26 && body + 26 <= bytes.length) {
        // WAVE_FORMAT_EXTENSIBLE: real format is the sub-format's first word.
        format = view.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      dataStart = body;
      // Streamed WAVs may carry 0 or 0xFFFFFFFF; clamp to what is there.
      dataLength = size.clamp(0, bytes.length - body);
      break;
    }
    offset = body + size + (size & 1);
  }

  if (format == null || dataStart < 0) {
    throw const FormatException('WAV is missing fmt or data chunk');
  }
  if (channels < 1 || channels > 2 || sampleRate <= 0) {
    throw FormatException('Unsupported WAV layout ($channels ch)');
  }
  final isFloat = format == 3 && bits == 32;
  final isPcm = format == 1 && (bits == 16 || bits == 24);
  if (!isFloat && !isPcm) {
    throw FormatException('Unsupported WAV encoding (format $format, $bits-bit)');
  }

  final bytesPerSample = bits ~/ 8;
  final frames = dataLength ~/ (bytesPerSample * channels);
  final left = Float32List(frames);
  final right = Float32List(frames);

  double read(int pos) {
    if (isFloat) return view.getFloat32(pos, Endian.little);
    if (bits == 16) return view.getInt16(pos, Endian.little) / 32768.0;
    final v =
        bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16);
    return (v >= 0x800000 ? v - 0x1000000 : v) / 8388608.0;
  }

  for (var i = 0; i < frames; i++) {
    final pos = dataStart + i * bytesPerSample * channels;
    final l = read(pos);
    left[i] = l;
    right[i] = channels == 2 ? read(pos + bytesPerSample) : l;
  }
  return (left: left, right: right, sampleRate: sampleRate);
}

String _tag(Uint8List bytes, int at) =>
    String.fromCharCodes(bytes.sublist(at, at + 4));
