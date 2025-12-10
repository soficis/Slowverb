import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/data/repositories/hive_history_repository.dart';
import 'package:slowverb/domain/entities/history_entry.dart';
import 'package:slowverb/domain/repositories/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HiveHistoryRepository();
});

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(() {
      return HistoryNotifier();
    });

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  @override
  Future<List<HistoryEntry>> build() async {
    return _repository.getRecent();
  }

  Future<void> addEntry(HistoryEntry entry) async {
    await _repository.addEntry(entry);
    // Refresh the list
    ref.invalidateSelf();
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    // Refresh the list
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    // Refresh the list
    ref.invalidateSelf();
  }
}
