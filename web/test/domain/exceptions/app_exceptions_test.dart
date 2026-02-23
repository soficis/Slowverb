import 'package:flutter_test/flutter_test.dart';
import 'package:slowverb_web/domain/exceptions/app_exceptions.dart';

void main() {
  group('StorageException', () {
    test('includes operation, key, and cause in toString', () {
      final error = StorageException('saveProject', 'project-1', StateError('write failed'));
      final text = error.toString();
      expect(text, contains('saveProject'));
      expect(text, contains('project-1'));
      expect(text, contains('write failed'));
    });
  });

  group('EngineException', () {
    test('includes operation and cause in toString', () {
      final error = EngineException('renderPreview', ArgumentError('invalid config'));
      final text = error.toString();
      expect(text, contains('renderPreview'));
      expect(text, contains('invalid config'));
    });
  });
}
