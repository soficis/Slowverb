import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:slowverb_web/data/repositories/project_repository_web.dart';
import 'package:slowverb_web/domain/entities/project.dart';

void main() {
  group('ProjectRepositoryWeb', () {
    test('saves and loads projects using IndexedDB factory', () async {
      final repository = ProjectRepositoryWeb(factory: newIdbFactoryMemory());
      await repository.initialize();

      final project = Project(
        id: 'project-1',
        name: 'Test Project',
        sourcePath: null,
        sourceHandleId: null,
        sourceFileName: 'track.mp3',
        sourceTitle: null,
        sourceArtist: null,
        durationMs: 1000,
        presetId: 'slowed_reverb',
        parameters: const {'tempo': 0.9},
        createdAt: DateTime.utc(2026, 2, 22),
        updatedAt: DateTime.utc(2026, 2, 22),
      );

      await repository.saveProject(project);

      final loaded = await repository.getProject(project.id);
      expect(loaded, isNotNull);
      expect(loaded!.name, project.name);
      expect(await repository.hasProject(project.id), isTrue);

      await repository.deleteProject(project.id);
      expect(await repository.hasProject(project.id), isFalse);
    });

    test('skips malformed records instead of dropping all projects', () async {
      final factory = newIdbFactoryMemory();
      final repository = ProjectRepositoryWeb(factory: factory);
      await repository.initialize();

      await repository.saveProject(
        const Project(
          id: 'good',
          name: 'Good',
          sourcePath: null,
          sourceHandleId: null,
          sourceFileName: null,
          sourceTitle: null,
          sourceArtist: null,
          durationMs: 1000,
          presetId: 'slowed_reverb',
          parameters: {'tempo': 0.9},
        ),
      );

      final db = await factory.open('slowverb_web');
      final txn = db.transaction('projects', 'readwrite');
      await txn.objectStore('projects').put({'id': 'bad'});
      await txn.completed;
      db.close();

      final projects = await repository.getAllProjects();
      expect(projects.map((p) => p.id), ['good']);
    });

    test('returns null for missing project handles', () async {
      final repository = ProjectRepositoryWeb(factory: newIdbFactoryMemory());
      await repository.initialize();

      final handle = await repository.getProjectHandle('missing');
      expect(handle, isNull);
    });
  });
}
