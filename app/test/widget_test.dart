// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb/data/repositories/project_repository.dart';
import 'package:slowverb/domain/entities/project.dart';
import 'package:slowverb/data/providers/project_providers.dart';
import 'package:slowverb/app/app.dart';

import 'package:slowverb/features/editor/editor_provider.dart';

class FakeProjectRepository implements ProjectRepository {
  @override
  Future<void> initialize() async {}

  @override
  List<Project> getAllProjects() => [];

  @override
  Future<void> saveProject(Project project) async {}

  @override
  Future<void> deleteProject(String id) async {}

  @override
  Project? getProject(String id) => null;

  @override
  bool hasProject(String id) => false;

  @override
  int get projectCount => 0;
}

class FakeEditorNotifier extends EditorNotifier {
  FakeEditorNotifier() {
    state = const EditorState();
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          editorProvider.overrideWith((ref) => FakeEditorNotifier()),
        ],
        child: const SlowverbApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify it builds without error
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
