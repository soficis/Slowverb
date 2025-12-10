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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:slowverb/app/app.dart';
import 'package:slowverb/data/repositories/project_repository.dart';
import 'package:slowverb/data/providers/project_providers.dart';
import 'package:slowverb/services/ffmpeg_service.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
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

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize repository
  final projectRepository = ProjectRepository();
  await projectRepository.initialize();

  // Initialize FFmpeg service on Windows (show progress dialog if needed)
  final ffmpegService = FFmpegService();
  if (Platform.isWindows) {
    try {
      await ffmpegService.initialize();
    } catch (e) {
      // FFmpeg initialization failed - will show error in UI if user tries to export
      debugPrint('FFmpeg initialization failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        projectRepositoryProvider.overrideWithValue(projectRepository),
        ffmpegServiceProvider.overrideWithValue(ffmpegService),
      ],
      child: const SlowverbApp(),
    ),
  );
}

// Provider for FFmpeg service
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  throw UnimplementedError('FFmpegService must be overridden');
});
