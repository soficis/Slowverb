import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:slowverb_web/domain/entities/streaming_source.dart';
import 'package:slowverb_web/domain/entities/visualizer_preset.dart';
import 'package:web/web.dart' as web;

/// Web Audio-based streaming engine for live remix/visualizer mode.
class StreamingAudioEngine {
  web.HTMLAudioElement? _mediaElement;
  web.AudioContext? _context;
  web.MediaElementAudioSourceNode? _sourceNode;
  web.AnalyserNode? _analyser;
  final _analysisController = StreamController<AudioAnalysisFrame>.broadcast();
  Timer? _analysisTimer;
  StreamingCapability _capability = StreamingCapability.unknown;
  StreamingSource? _source;

  StreamingCapability get capability => _capability;

  Stream<AudioAnalysisFrame> get analysisStream => _analysisController.stream;

  Future<StreamingCapability> attach(StreamingSource source) async {
    await dispose();
    _source = source;

    if (source.isYouTube) {
      // Visualizer-only for YouTube embeds.
      _capability = StreamingCapability.visualizerOnly;
      _startFakeAnalysis();
      return _capability;
    }

    try {
      final element = web.HTMLAudioElement()
        ..src = source.url.toString()
        ..crossOrigin = 'anonymous'
        ..preload = 'auto';

      final ctx = web.AudioContext();
      final analyser = ctx.createAnalyser()
        ..fftSize = 1024
        ..smoothingTimeConstant = 0.8;

      final sourceNode = ctx.createMediaElementSource(element);
      sourceNode.connect(analyser);
      analyser.connect(ctx.destination);

      _context = ctx;
      _mediaElement = element;
      _sourceNode = sourceNode;
      _analyser = analyser;
      _capability = StreamingCapability.fullEffects;

      _startAnalysisTimer();
    } catch (_) {
      _capability = StreamingCapability.visualizerOnly;
      _startFakeAnalysis();
    }

    return _capability;
  }

  Future<void> play() async {
    if (_context != null && _context!.state == 'suspended') {
      await _context!.resume().toDart;
    }
    await _mediaElement?.play().toDart;
  }

  Future<void> pause() async {
    _mediaElement?.pause();
  }

  Future<void> seek(Duration position) async {
    if (_mediaElement == null) return;
    _mediaElement!.currentTime = position.inMilliseconds / 1000.0;
  }

  Future<void> dispose() async {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _sourceNode?.disconnect();
    _analyser?.disconnect();
    _mediaElement?.pause();
    _mediaElement = null;
    _sourceNode = null;
    _analyser = null;
    _context = null;
  }

  void _startAnalysisTimer() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final analyser = _analyser;
      final element = _mediaElement;
      if (analyser == null || element == null) return;

      final binCount = analyser.frequencyBinCount;
      final freqData = Uint8List(binCount);
      analyser.getByteFrequencyData(freqData.toJS);

      final spectrum = List<double>.generate(
        min(64, binCount),
        (i) => freqData[i] / 255.0,
      );

      final rms = spectrum.isEmpty
          ? 0.0
          : spectrum.reduce((a, b) => a + b) / spectrum.length;

      double bandAverage(int start, int end) {
        if (start >= end || end > spectrum.length) return 0.0;
        final slice = spectrum.sublist(start, end);
        if (slice.isEmpty) return 0.0;
        return slice.reduce((a, b) => a + b) / slice.length;
      }

      final bass = bandAverage(0, spectrum.length ~/ 4);
      final mid = bandAverage(spectrum.length ~/ 4, spectrum.length ~/ 2);
      final treble = bandAverage(spectrum.length ~/ 2, spectrum.length);

      final frame = AudioAnalysisFrame(
        spectrum: spectrum,
        rms: rms,
        bass: bass,
        mid: mid,
        treble: treble,
        time: Duration(milliseconds: (element.currentTime * 1000).round()),
      );

      _analysisController.add(frame);
    });
  }

  void _startFakeAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _analysisController.add(
        AudioAnalysisFrame(
          spectrum: const [],
          rms: 0,
          bass: 0,
          mid: 0,
          treble: 0,
          time: Duration(milliseconds: timer.tick * 200),
        ),
      );
    });
  }
}
