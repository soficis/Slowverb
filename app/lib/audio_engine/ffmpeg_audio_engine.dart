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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_audio/log_level.dart';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:slowverb/domain/repositories/audio_engine.dart';
import 'package:slowverb/domain/entities/batch_job.dart';
import 'package:slowverb/domain/entities/batch_render_progress.dart';
import 'package:slowverb/domain/entities/effect_preset.dart';
import 'package:slowverb/services/ffmpeg_service.dart';

/// FFmpeg-based implementation of AudioEngine
class FFmpegAudioEngine implements AudioEngine {
  final FFmpegService? _ffmpegService;

  bool _isInitialized = false;
  StreamController<double>? _renderProgressController;

  FFmpegAudioEngine([this._ffmpegService]);

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await _renderProgressController?.close();
  }

  @override
  Future<bool> isAvailable() async {
    return true;
  }

  @override
  Future<String> startPreview({
    required String sourcePath,
    required Map<String, double> params,
  }) async {
    _ensureInitialized();
    return sourcePath; // Placeholder
  }

  @override
  Future<void> stopPreview() async {
    // TODO: Cancel any ongoing preview render
  }

  @override
  Stream<double> render({
    required String sourcePath,
    required Map<String, double> params,
    required String outputPath,
    required String format,
    int? bitrateKbps,
  }) {
    _ensureInitialized();

    print(
      '[FFmpeg] render source=$sourcePath -> $outputPath format=$format bitrate=$bitrateKbps params=$params',
    );

    _renderProgressController = StreamController<double>();

    // Start render in background
    _executeRender(
      sourcePath: sourcePath,
      params: params,
      outputPath: outputPath,
      format: format,
      bitrateKbps: bitrateKbps,
    );

    return _renderProgressController!.stream;
  }

  Future<void> _executeRender({
    required String sourcePath,
    required Map<String, double> params,
    required String outputPath,
    required String format,
    int? bitrateKbps,
  }) async {
    final controller = _renderProgressController;
    if (controller == null) return;

    try {
      // Ensure output directory exists
      final outDir = File(outputPath).parent;
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final filterChain = _buildFilterChain(params);
      final bitrateArg = bitrateKbps != null ? '-b:a ${bitrateKbps}k' : '';
      // Avoid hard-coding encoders on Android; let ffmpeg pick built-in ones
      final codecArg = '';
      const rateChannels = '-ar 44100 -ac 2';

      // Build FFmpeg command arguments (inner part)
      // Note: For native process execution we need individual args, not one string.
      // For ffmpeg_kit we need one string.

      final commandStr =
          '-y -i "$sourcePath" '
          '-af "$filterChain" '
          '$codecArg '
          '$bitrateArg '
          '$rateChannels '
          '-threads 0 '
          '"$outputPath"';

      // Log the command for debugging
      // (Paths are already quoted)
      print('[FFmpeg] command: $commandStr');

      // Execute based on platform
      if (Platform.isWindows) {
        await _executeWindowsRender(commandStr, controller);
      } else {
        await _executeMobileRender(commandStr, controller);
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    }
  }

  Future<void> _executeWindowsRender(
    String commandArgsString,
    StreamController<double> controller,
  ) async {
    // Use the path from FFmpegService if available, otherwise fallback to 'ffmpeg'
    final ffmpegExe = _ffmpegService?.executablePath ?? 'ffmpeg';

    print('Executing Windows FFmpeg: $ffmpegExe $commandArgsString');

    try {
      final process = await Process.start(
        ffmpegExe,
        _splitArgs(commandArgsString),
        runInShell: true,
      );

      // Capture stdout/stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        // print('FFmpeg Stderr: $data');
        controller.add(0.5); // Indeterminate progress
      });

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        controller.add(1.0);
        controller.close();
      } else {
        controller.addError('FFmpeg exited with code $exitCode');
        controller.close();
      }
    } catch (e) {
      controller.addError('Failed to run ffmpeg ($ffmpegExe). Error: $e');
      controller.close();
    }
  }

  Future<void> _executeMobileRender(
    String command,
    StreamController<double> controller,
  ) async {
    // Make logs verbose so we can diagnose failures on device
    await FFmpegKitConfig.setLogLevel(LogLevel.AV_LOG_INFO);

    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        final logs = await session.getLogsAsString();
        final failStack = await session.getFailStackTrace();
        final state = await session.getState();
        final duration = await session.getDuration();

        if (ReturnCode.isSuccess(returnCode)) {
          print('[FFmpeg] success');
          controller.add(1.0);
          controller.close();
        } else {
          print(
            '[FFmpeg] failed rc=$returnCode state=$state duration=$duration',
          );
          print('[FFmpeg] logs: $logs');
          if (failStack != null) {
            print('[FFmpeg] fail stack: $failStack');
          }
          controller.addError('FFmpeg failed: $logs');
          controller.close();
        }
      },
      (log) {
        final msg = log.getMessage();
        if (msg.isNotEmpty) {
          print('[FFmpeg][log] $msg');
        }
      },
      (statistics) {
        controller.add(0.5);
      },
    );
  }

  // Basic arg splitter that handles quotes
  List<String> _splitArgs(String command) {
    final args = <String>[];
    var current = '';
    var inQuote = false;

    for (var i = 0; i < command.length; i++) {
      final char = command[i];
      if (char == '"') {
        inQuote = !inQuote;
      } else if (char == ' ' && !inQuote) {
        if (current.isNotEmpty) {
          args.add(current);
          current = '';
        }
      } else {
        current += char;
      }
    }
    if (current.isNotEmpty) args.add(current);
    return args;
  }

  @override
  Future<void> cancelRender() async {
    if (!Platform.isWindows) {
      await FFmpegKit.cancel();
    }
    // On Windows, we'd need the process object to kill it.
    // Simplified for now.
    await _renderProgressController?.close();
    _renderProgressController = null;
  }

  /// Build the FFmpeg filter chain from parameters
  String _buildFilterChain(Map<String, double> params) {
    final tempo = params['tempo'] ?? 1.0;
    final pitch = params['pitch'] ?? 0.0;
    final reverbAmount = params['reverbAmount'] ?? 0.0;
    final wetDryMix = params['wetDryMix'] ?? 0.0;
    final eqWarmth = params['eqWarmth'] ?? 0.0;

    final filters = <String>[];

    // Tempo adjustment (chain atempo for extreme values)
    if (tempo != 1.0) {
      filters.add(_buildTempoFilter(tempo));
    }

    // Pitch shifting via sample rate adjustment
    if (pitch != 0.0) {
      filters.add(_buildPitchFilter(pitch));
    }

    // Reverb via aecho
    if (reverbAmount > 0) {
      filters.add(_buildReverbFilter(reverbAmount));
    }

    // Echo / delay mix
    if (wetDryMix > 0) {
      filters.add(_buildEchoFilter(wetDryMix));
    }

    // Warmth EQ (gentle low-shelf)
    if (eqWarmth > 0) {
      filters.add(_buildWarmthFilter(eqWarmth));
    }

    return filters.isEmpty ? 'anull' : filters.join(',');
  }

  /// Build atempo filter, chaining if needed for extreme values
  String _buildTempoFilter(double tempo) {
    // atempo only supports 0.5 to 2.0, chain for more extreme values
    if (tempo >= 0.5 && tempo <= 2.0) {
      return 'atempo=$tempo';
    } else if (tempo < 0.5) {
      // Chain multiple atempo filters
      final factor1 = 0.5;
      final factor2 = tempo / factor1;
      return 'atempo=$factor1,atempo=$factor2';
    } else {
      // tempo > 2.0
      final factor1 = 2.0;
      final factor2 = tempo / factor1;
      return 'atempo=$factor1,atempo=$factor2';
    }
  }

  /// Build pitch shift filter using asetrate + aresample
  String _buildPitchFilter(double semitones) {
    // Convert semitones to rate multiplier using 2^(n/12)
    final multiplier = math.pow(2.0, semitones / 12.0);
    return 'asetrate=44100*$multiplier,aresample=44100';
  }

  /// Build reverb filter using aecho
  String _buildReverbFilter(double amount) {
    // Map amount (0-1) to aecho parameters
    // aecho=in_gain:out_gain:delays:decays
    final decay = 0.2 + (amount * 0.5); // 0.2 to 0.7
    final delay = 40 + (amount * 80).toInt(); // 40ms to 120ms

    return 'aecho=0.8:0.88:$delay:$decay';
  }

  /// Build echo/delay mix using aecho scaled from wetDryMix
  String _buildEchoFilter(double mix) {
    // mix 0-1 -> decay 0.1-0.9 and delay 120-240ms
    final decay = 0.1 + (mix * 0.8);
    final delay = 120 + (mix * 120).toInt();
    return 'aecho=0.9:0.9:$delay:$decay';
  }

  /// Gentle low-shelf warmth boost
  String _buildWarmthFilter(double warmth) {
    // Gain from 0 to +9dB, shelf at 200Hz
    final gain = (warmth * 9).toStringAsFixed(1);
    return 'bass=g=$gain:f=200';
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('AudioEngine not initialized. Call initialize() first.');
    }
  }

  // Batch interface implementation
  @override
  Stream<BatchRenderProgress> renderBatch({
    required List<BatchInputFile> files,
    required EffectPreset defaultPreset,
    required ExportOptions options,
    int concurrency = 1,
  }) async* {
    var completedCount = 0;
    var failedCount = 0;

    // Initial progress yield
    yield BatchRenderProgress.initial(files.length);

    for (var i = 0; i < files.length; i++) {
      final item = files[i];

      // Update progress: started processing file i
      yield BatchRenderProgress(
        totalFiles: files.length,
        completedFiles: completedCount,
        failedFiles: failedCount,
        currentFileIndex: i,
        currentFileProgress: 0.0,
        overallProgress: i / files.length,
      );

      final completer = Completer<void>();
      final controller = StreamController<double>();
      _renderProgressController =
          controller; // Hijack controller for single-thread

      final preset = item.presetOverride ?? defaultPreset;
      final params = preset.toParametersMap();

      _executeRender(
        sourcePath: item.sourcePath,
        params: params,
        outputPath: _generateOutputPath(item.sourcePath, options),
        format: options.format,
        bitrateKbps: options.bitrateKbps,
      );

      controller.stream.listen(
        (progress) {},
        onError: (e) {
          failedCount++;
          completer.complete();
        },
        onDone: () {
          completedCount++;
          completer.complete();
        },
      );

      await completer.future;

      // Update progress: finished processing file i
      yield BatchRenderProgress(
        totalFiles: files.length,
        completedFiles: completedCount,
        failedFiles: failedCount,
        currentFileIndex: i,
        currentFileProgress: 1.0,
        overallProgress: (i + 1) / files.length,
      );
    }

    // Final completion yield
    yield BatchRenderProgress(
      totalFiles: files.length,
      completedFiles: completedCount,
      failedFiles: failedCount,
      currentFileIndex: -1,
      overallProgress: 1.0,
    );
  }

  // Helper to generate output path (simplified)
  String _generateOutputPath(String source, ExportOptions options) {
    final dir = File(source).parent.path;
    final name = File(source).uri.pathSegments.last.split('.').first;
    return '$dir/${name}_slowed.${options.format}';
  }

  @override
  Future<void> cancelBatch() async {
    await cancelRender();
  }

  @override
  Future<void> pauseBatch() async {}

  @override
  Future<void> resumeBatch() async {}
}
