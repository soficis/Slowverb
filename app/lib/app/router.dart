import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slowverb/features/editor/editor_screen.dart';
import 'package:slowverb/features/effects/effect_selection_screen.dart';
import 'package:slowverb/features/export/export_screen.dart';
import 'package:slowverb/features/library/library_screen.dart';
import 'package:slowverb/features/splash/splash_screen.dart';

/// Application route paths
abstract final class RoutePaths {
  static const splash = '/splash';
  static const home = '/';
  static const effects = '/effects';
  static const editor = '/editor/:projectId';
  static const export = '/export/:projectId';

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

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
