import 'package:slowverb_web/domain/repositories/audio_engine.dart';

/// Builds FFmpeg filter chains from effect configurations
///
/// Translates high-level effect parameters (tempo, pitch, reverb)
/// into FFmpeg audio filter syntax.
class FilterChainBuilder {
  /// Build complete FFmpeg command for exporting audio
  String buildExportCommand({
    required String inputFile,
    required String outputFile,
    required String filterChain,
    required String format,
    int? bitrateKbps,
    int? compressionLevel,
  }) {
    final parts = <String>['-i', inputFile];

    if (filterChain.isNotEmpty && filterChain != 'anull') {
      parts.addAll(['-af', filterChain]);
    }

    // Add codec-specific args
    parts.addAll(_getCodecArgs(format, bitrateKbps, compressionLevel));

    parts.add(outputFile);

    return parts.join(' ');
  }

  /// Build filter chain string from effect configuration
  String buildFilterChain(EffectConfig config) {
    final filters = <String>[];

    // Tempo adjustment
    if (config.tempo != 1.0) {
      filters.add(_buildTempoFilter(config.tempo));
    }

    // Pitch shifting
    if (config.pitchSemitones != 0.0) {
      filters.add(_buildPitchFilter(config.pitchSemitones));
    }

    // EQ warmth (boost low-mids)
    if (config.eqWarmth > 0.0) {
      filters.add(_buildEqWarmthFilter(config.eqWarmth));
    }

    // Reverb
    if (config.reverbAmount > 0.0) {
      filters.add(
        _buildReverbFilter(
          amount: config.reverbAmount,
          preDelayMs: config.preDelayMs ?? 30,
          roomScale: config.roomScale ?? 0.7,
        ),
      );
    }

    // Echo (separate from reverb)
    if (config.echoAmount > 0.0) {
      filters.add(_buildEchoFilter(config.echoAmount));
    }

    // HF damping (low-pass filter)
    if (config.hfDamping != null && config.hfDamping! > 0.0) {
      filters.add(_buildHfDampingFilter(config.hfDamping!));
    }

    // Stereo width adjustment
    if (config.stereoWidth != null && config.stereoWidth! != 1.0) {
      filters.add(_buildStereoWidthFilter(config.stereoWidth!));
    }

    return filters.isEmpty ? 'anull' : filters.join(',');
  }

  /// Build atempo filter, chaining if needed for values outside 0.5-2.0
  String _buildTempoFilter(double tempo) {
    final parts = <String>[];
    var remaining = tempo;

    // atempo only supports 0.5 to 2.0, chain for extreme values
    while (remaining < 0.5 || remaining > 2.0) {
      if (remaining < 0.5) {
        parts.add('atempo=0.5');
        remaining /= 0.5;
      } else {
        parts.add('atempo=2.0');
        remaining /= 2.0;
      }
    }

    parts.add('atempo=${remaining.toStringAsFixed(4)}');
    return parts.join(',');
  }

  /// Build pitch shift filter using asetrate + aresample
  String _buildPitchFilter(double semitones) {
    // Convert semitones to rate multiplier: rate = 2^(semitones/12)
    final multiplier = _semitonesToRate(semitones);
    return 'asetrate=44100*$multiplier,aresample=44100';
  }

  /// Build reverb filter using aecho
  String _buildReverbFilter({
    required double amount,
    required double preDelayMs,
    required double roomScale,
  }) {
    final delay = preDelayMs.toInt();
    final delay2 = (delay * (1 + roomScale * 0.5)).toInt();
    final delay3 = (delay * (1 + roomScale)).toInt();

    final decay1 = (amount * 0.9).toStringAsFixed(2);
    final decay2 = (amount * 0.7).toStringAsFixed(2);
    final decay3 = (amount * 0.4).toStringAsFixed(2);

    return 'aecho=0.8:0.88:$delay|$delay2|$delay3:$decay1|$decay2|$decay3';
  }

  /// Build echo filter (for super slow echo preset)
  String _buildEchoFilter(double amount) {
    final delay = (500 * amount).toInt();
    final decay = (amount * 0.6).toStringAsFixed(2);
    return 'aecho=0.8:0.9:$delay:$decay';
  }

  /// Build EQ warmth filter (boost 300Hz)
  String _buildEqWarmthFilter(double warmth) {
    final gain = (warmth * 6).toStringAsFixed(1);
    return 'equalizer=f=300:t=h:width=200:g=$gain';
  }

  /// Build HF damping filter (low-pass)
  String _buildHfDampingFilter(double damping) {
    // Map damping 0-1 to cutoff frequency 20kHz-2kHz
    final cutoffFreq = (20000 - (damping * 18000)).toInt();
    return 'lowpass=f=$cutoffFreq';
  }

  /// Build stereo width adjustment filter
  String _buildStereoWidthFilter(double width) {
    // Use extrastereo or apulsator based on width
    if (width < 1.0) {
      // Narrow stereo field
      final mix = (1.0 - width).toStringAsFixed(2);
      return 'stereotools=mlev=$mix';
    } else {
      // Widen stereo field
      final enhance = ((width - 1.0) * 2 + 1).toStringAsFixed(2);
      return 'extrastereo=m=$enhance';
    }
  }

  /// Get codec-specific arguments for FFmpeg
  List<String> _getCodecArgs(
    String format,
    int? bitrateKbps,
    int? compressionLevel,
  ) {
    switch (format) {
      case 'mp3':
        final bitrate = bitrateKbps ?? 320;
        return ['-c:a', 'libmp3lame', '-b:a', '${bitrate}k'];

      case 'wav':
        return ['-c:a', 'pcm_s16le'];

      case 'flac':
        final level = compressionLevel ?? 8;
        return ['-c:a', 'flac', '-compression_level', '$level'];

      default:
        throw UnsupportedError('Format $format not supported');
    }
  }

  /// Convert semitones to rate multiplier
  double _semitonesToRate(double semitones) {
    // 2^(semitones/12)
    // -2 semitones → 0.8909
    // +3 semitones → 1.1892
    return _pow(2, semitones / 12);
  }

  /// Helper for power calculation (dart:math not imported)
  double _pow(double base, double exponent) {
    if (exponent == 0) return 1.0;
    if (exponent < 0) return 1.0 / _pow(base, -exponent);
    var result = 1.0;
    for (var i = 0; i < exponent.abs(); i++) {
      result *= base;
    }
    // Handle fractional exponents with approximation
    if (exponent % 1 != 0) {
      // Use Taylor series approximation for 2^x
      final x = exponent;
      return 1 + x * 0.693147 + x * x * 0.240226 + x * x * x * 0.055504;
    }
    return result;
  }
}
