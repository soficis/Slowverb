import 'package:slowverb/domain/entities/history_entry.dart';

/// Interface for managing history entries.
abstract class HistoryRepository {
  /// Retrieves the most recent history entries.
  /// [limit] specifies the maximum number of entries to return.
  Future<List<HistoryEntry>> getRecent({int limit = 50});

  /// Adds a new entry to the history.
  Future<void> addEntry(HistoryEntry entry);

  /// Deletes an entry by its ID.
  Future<void> deleteEntry(String id);

  /// Clears all history entries.
  Future<void> clearAll();
}
