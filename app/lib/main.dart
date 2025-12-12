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
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slowverb/app/app.dart';
import 'package:slowverb/data/repositories/project_repository.dart';
import 'package:slowverb/data/providers/project_providers.dart';
import 'package:slowverb/services/ffmpeg_service.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface all uncaught Flutter errors instead of silently failing.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(details.toString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  runApp(const _StartupApp());
}

// Provider for FFmpeg service
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  throw UnimplementedError('FFmpegService must be overridden');
});

/// Root widget that bootstraps storage/FFmpeg before showing the app
class _StartupApp extends StatefulWidget {
  const _StartupApp();

  @override
  State<_StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<_StartupApp> {
  late final Future<_StartupResult> _initFuture = _initialize();

  Future<_StartupResult> _initialize() async {
    // Desktop window plumbing
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    final hiveDir = await _preferredHiveDir();

    // Initialize Hive in an app-specific directory so sandboxed platforms can lock files.
    try {
      Hive.init(hiveDir.path);
    } catch (e, st) {
      debugPrint('Hive.init failed for ${hiveDir.path}, falling back to temp dir: $e\n$st');
      final fallbackDir = await _fallbackHiveDir();
      Hive.init(fallbackDir.path);
    }

    final projectRepository = ProjectRepository();
    try {
      await projectRepository.initialize();
    } catch (e, st) {
      debugPrint('Startup storage init error: $e\n$st');
      throw Exception(
        'Failed to initialize local storage. Please clear app data and try again.\n$e',
      );
    }

    final ffmpegService = FFmpegService();
    if (Platform.isWindows || Platform.isMacOS) {
      try {
        debugPrint('Initializing FFmpeg for ${Platform.operatingSystem}...');
        await ffmpegService.initialize();
        debugPrint(
          'FFmpeg initialization complete: ${ffmpegService.executablePath}',
        );
      } catch (e, st) {
        debugPrint('FFmpeg initialization failed: $e\n$st');
        // Non-fatal - continue without FFmpeg on desktop.
      }
    } else if (Platform.isAndroid) {
      // Initialize FFmpeg for Android via ffmpeg_kit_flutter
      try {
        // The ffmpeg_kit_flutter plugin initializes automatically
        debugPrint('FFmpeg Kit Flutter initialized for Android');
      } catch (e, st) {
        debugPrint('FFmpeg Kit Flutter initialization failed: $e\n$st');
      }
    }

    return _StartupResult(
      projectRepository: projectRepository,
      ffmpegService: ffmpegService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StartupLoading();
        }
        if (snapshot.hasError) {
          return StartupErrorApp(errorMessage: snapshot.error.toString());
        }

        final result = snapshot.data!;
        return ProviderScope(
          overrides: [
            projectRepositoryProvider.overrideWithValue(
              result.projectRepository,
            ),
            ffmpegServiceProvider.overrideWithValue(result.ffmpegService),
          ],
          child: const SlowverbApp(),
        );
      },
    );
  }
}

Future<Directory> _preferredHiveDir() async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/storage');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  } catch (e, st) {
    debugPrint('Failed to resolve application support directory: $e\n$st');
    return _fallbackHiveDir();
  }
}

Future<Directory> _fallbackHiveDir() async {
  final dir = Directory('${Directory.systemTemp.path}/slowverb_hive');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

class _StartupResult {
  final ProjectRepository projectRepository;
  final FFmpegService ffmpegService;

  _StartupResult({
    required this.projectRepository,
    required this.ffmpegService,
  });
}

/// Simple loading surface shown while we hydrate storage and plugins.
class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1034), Color(0xFF0B132B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Starting Slowverb...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal error surface shown when startup dependencies fail to init.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slowverb',
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Startup error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
