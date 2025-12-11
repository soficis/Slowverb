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
import 'package:slowverb/features/editor/editor_screen.dart';
import 'package:slowverb/features/effects/effect_selection_screen.dart';
import 'package:slowverb/features/export/export_screen.dart';
import 'package:slowverb/features/library/library_screen.dart';
import 'package:slowverb/features/splash/splash_screen.dart';
import 'package:slowverb/features/history/history_screen.dart';
import 'package:slowverb/features/batch/batch_import_screen.dart';
import 'package:slowverb/features/batch/batch_playlist_screen.dart';

/// Application route paths
abstract final class RoutePaths {
  static const splash = '/splash';
  static const home = '/';
  static const effects = '/effects';
  static const editor = '/editor/:projectId';
  static const export = '/export/:projectId';
  static const history = '/history';
  static const batch = '/batch';
  static const batchPlaylist = '/batch/playlist';

  /// Build editor path with project ID
  static String editorWithId(String projectId) => '/editor/$projectId';

  /// Build export path with project ID
  static String exportWithId(String projectId) => '/export/$projectId';
}

/// Application router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: 'splash',
      pageBuilder: (context, state) => _buildPageWithFadeTransition(
        state: state,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.home,
      name: 'home',
      pageBuilder: (context, state) => _buildPageWithFadeTransition(
        state: state,
        child: const LibraryScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.effects,
      name: 'effects',
      pageBuilder: (context, state) => _buildPageWithSlideTransition(
        state: state,
        child: const EffectSelectionScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.editor,
      name: 'editor',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['projectId'] ?? '';
        return _buildPageWithSlideTransition(
          state: state,
          child: EditorScreen(projectId: projectId),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.export,
      name: 'export',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['projectId'] ?? '';
        return _buildPageWithSlideTransition(
          state: state,
          child: ExportScreen(projectId: projectId),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.history,
      name: 'history',
      pageBuilder: (context, state) => _buildPageWithSlideTransition(
        state: state,
        child: const HistoryScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.batch,
      name: 'batch',
      pageBuilder: (context, state) => _buildPageWithSlideTransition(
        state: state,
        child: const BatchImportScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.batchPlaylist,
      name: 'batch_playlist',
      pageBuilder: (context, state) => _buildPageWithSlideTransition(
        state: state,
        child: const BatchPlaylistScreen(),
      ),
    ),
  ],
);

/// Builds a page with fade transition animation
CustomTransitionPage<void> _buildPageWithFadeTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Builds a page with slide transition animation
CustomTransitionPage<void> _buildPageWithSlideTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
