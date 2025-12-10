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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/features/import/import_screen.dart';
import 'package:slowverb_web/features/editor/editor_screen.dart';
import 'package:slowverb_web/features/export/export_screen.dart';
import 'package:slowverb_web/features/about/about_screen.dart';
import 'package:slowverb_web/features/youtube/youtube_stream_screen.dart';
import 'package:slowverb_web/app/app_config.dart';

/// App navigation routes
class AppRoutes {
  static const import_ = '/';
  static const editor = '/editor';
  static const presets = '/presets';
  static const export = '/export';
  static const about = '/about';
  static const youtube = '/youtube';
}

/// Router configuration for Slowverb Web
final appRouter = GoRouter(
  initialLocation: AppRoutes.import_,
  routes: [
    GoRoute(
      path: AppRoutes.import_,
      name: 'import',
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: AppRoutes.editor,
      name: 'editor',
      builder: (context, state) {
        final fileData = state.extra as AudioFileData?;
        return EditorScreen(fileData: fileData);
      },
    ),
    GoRoute(
      path: AppRoutes.presets,
      name: 'presets',
      builder: (context, state) {
        // TODO: Implement PresetsScreen
        return const Scaffold(
          body: Center(child: Text('Presets Screen - Coming Soon')),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.export,
      name: 'export',
      builder: (context, state) => const ExportScreen(),
    ),
    GoRoute(
      path: AppRoutes.about,
      name: 'about',
      builder: (context, state) => const AboutScreen(),
    ),
    // YouTube streaming (experimental)
    if (AppConfig.enableExperimentalYouTubeMode)
      GoRoute(
        path: AppRoutes.youtube,
        name: 'youtube',
        builder: (context, state) => const YouTubeStreamScreen(),
      ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Page not found: ${state.uri}'),
        ],
      ),
    ),
  ),
);
