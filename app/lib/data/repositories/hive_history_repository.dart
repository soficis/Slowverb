import 'package:hive_flutter/hive_flutter.dart';
import 'package:slowverb/domain/entities/history_entry.dart';
import 'package:slowverb/domain/repositories/history_repository.dart';

class HiveHistoryRepository implements HistoryRepository {
  static const String _boxName = 'slowverb_history';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  @override
  Future<void> addEntry(HistoryEntry entry) async {
    final box = await _getBox();
    await box.put(entry.id, entry.toJson());
  }

  @override
  Future<List<HistoryEntry>> getRecent({int limit = 50}) async {
    final box = await _getBox();
    final entries = box.values
        .map((e) {
          try {
            // Hive stores Maps as Map<dynamic, dynamic>, need to cast to Map<String, dynamic>
            final jsonMap = Map<String, dynamic>.from(e as Map);
            return HistoryEntry.fromJson(jsonMap);
          } catch (e) {
            // Handle potentially corrupt entries gracefully
            return null;
          }
        })
        .whereType<HistoryEntry>() // Filter out nulls
        .toList();

    // Sort by timestamp descending (newest first)
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (entries.length > limit) {
      return entries.sublist(0, limit);
    }
    return entries;
  }

  @override
  Future<void> deleteEntry(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
