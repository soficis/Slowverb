class StorageException implements Exception {
  final String operation;
  final String key;
  final Object? cause;

  const StorageException(this.operation, this.key, [this.cause]);

  @override
  String toString() => 'StorageException($operation, key=$key): $cause';
}

class EngineException implements Exception {
  final String operation;
  final Object? cause;

  const EngineException(this.operation, [this.cause]);

  @override
  String toString() => 'EngineException($operation): $cause';
}
