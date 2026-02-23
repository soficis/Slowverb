import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/exceptions/slowverb_exceptions.dart';

void main() {
  group('SlowverbException hierarchy', () {
    group('AudioProcessingException', () {
      test('creates exception with message only', () {
        final exception = AudioProcessingException('Test error');
        expect(exception.message, 'Test error');
        expect(exception.cause, isNull);
        expect(exception.sourcePath, isNull);
        expect(exception.effectParams, isNull);
      });

      test('creates exception with all parameters', () {
        final cause = Exception('Original error');
        final exception = AudioProcessingException(
          'Processing failed',
          cause: cause,
          sourcePath: '/path/to/audio.mp3',
          effectParams: {'tempo': 0.8, 'reverb': 0.5},
        );
        expect(exception.message, 'Processing failed');
        expect(exception.cause, cause);
        expect(exception.sourcePath, '/path/to/audio.mp3');
        expect(exception.effectParams, {'tempo': 0.8, 'reverb': 0.5});
      });

      test('toString includes source path when provided', () {
        final exception = AudioProcessingException(
          'Test error',
          sourcePath: '/test/path.mp3',
        );
        expect(exception.toString(), contains('/test/path.mp3'));
      });
    });

    group('FileOperationException', () {
      test('creates exception with operation', () {
        final exception = FileOperationException(
          'Failed to read file',
          operation: 'read',
          filePath: '/path/to/file.wav',
        );
        expect(exception.message, 'Failed to read file');
        expect(exception.operation, 'read');
        expect(exception.filePath, '/path/to/file.wav');
      });

      test('toString includes operation and path', () {
        final exception = FileOperationException(
          'Failed',
          operation: 'write',
          filePath: '/output.mp3',
        );
        final str = exception.toString();
        expect(str, contains('write'));
        expect(str, contains('/output.mp3'));
      });
    });

    group('MasteringException', () {
      test('creates exception with error code', () {
        final exception = MasteringException(
          'WASM error',
          errorCode: -1,
          masteringLevel: 5,
        );
        expect(exception.errorCode, -1);
        expect(exception.masteringLevel, 5);
      });

      test('toString includes level and code', () {
        final exception = MasteringException(
          'Failed',
          errorCode: 42,
          masteringLevel: 3,
        );
        final str = exception.toString();
        expect(str, contains('level: 3'));
        expect(str, contains('code: 42'));
      });
    });

    group('ExportException', () {
      test('creates exception with format and path', () {
        final exception = ExportException(
          'Export failed',
          format: 'flac',
          outputPath: '/export/output.flac',
        );
        expect(exception.format, 'flac');
        expect(exception.outputPath, '/export/output.flac');
      });
    });

    group('ProjectNotFoundException', () {
      test('creates exception from project ID', () {
        final exception = ProjectNotFoundException('proj-123');
        expect(exception.projectId, 'proj-123');
        expect(exception.message, 'Project not found: proj-123');
        expect(exception.cause, isNull);
      });
    });

    group('EngineException', () {
      test('creates exception with operation', () {
        final cause = StateError('Invalid state');
        final exception = EngineException(
          'Engine failed',
          operation: 'initialize',
          cause: cause,
        );
        expect(exception.operation, 'initialize');
        expect(exception.cause, isA<StateError>());
      });
    });
  });
}
