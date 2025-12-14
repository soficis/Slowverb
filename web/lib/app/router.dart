import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb_web/domain/entities/audio_file_data.dart';
import 'package:slowverb_web/domain/entities/project.dart';
import 'package:slowverb_web/features/import/import_screen.dart';
import 'package:slowverb_web/features/editor/editor_screen.dart';
import 'package:slowverb_web/features/export/export_screen.dart';
import 'package:slowverb_web/features/about/about_screen.dart';
import 'package:slowverb_web/features/library/library_screen.dart';
import 'package:slowverb_web/features/settings/settings_screen.dart';

/// Arguments for navigating to the editor.
class EditorScreenArgs {
  final AudioFileData? fileData;
  final Project? project;

  const EditorScreenArgs({this.fileData, this.project});
}

/// App navigation routes
class AppRoutes {
  static const import_ = '/';
  static const editor = '/editor';
  static const presets = '/presets';
  static const export = '/export';
  static const about = '/about';
  static const library = '/library';
  static const settings = '/settings';
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
        final extra = state.extra;
        AudioFileData? fileData;
        Project? project;
        if (extra is EditorScreenArgs) {
          fileData = extra.fileData;
          project = extra.project;
        } else if (extra is AudioFileData) {
          fileData = extra;
        }
        return EditorScreen(fileData: fileData, project: project);
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
    GoRoute(
      path: AppRoutes.library,
      name: 'library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
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
