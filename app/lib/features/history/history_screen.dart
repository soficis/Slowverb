import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:slowverb/app/router.dart';
import 'package:slowverb/domain/entities/history_entry.dart';
import 'package:slowverb/features/history/history_provider.dart';
import 'package:slowverb/features/history/batch_export_dialog.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('History'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(RoutePaths.home),
              ),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: 'Select Items',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text(
                      'Are you sure you want to delete all history entries? Files will remain on disk.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(historyProvider.notifier).clearAll();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Clear All',
            ),
          ],
        ],
      ),
      body: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No history yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupEntries(entries);
          return ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      group.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...group.entries.map(
                    (entry) => _HistoryItem(
                      entry,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedIds.contains(entry.id),
                      onSelectionToggle: () => _toggleSelection(entry.id),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final historyData = await ref.read(historyProvider.future);
                final selectedEntries = historyData
                    .where((e) => _selectedIds.contains(e.id))
                    .toList();

                if (!mounted) return;

                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      BatchExportDialog(entries: selectedEntries),
                );

                if (result == true) {
                  // Exit selection mode after starting batch
                  _toggleSelectionMode();
                }
              },
              icon: const Icon(Icons.file_download),
              label: const Text('Batch Export'),
            )
          : null,
    );
  }

  List<_DateGroup> _groupEntries(List<HistoryEntry> entries) {
    if (entries.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_DateGroup>[];
    final todayEntries = <HistoryEntry>[];
    final yesterdayEntries = <HistoryEntry>[];
    final olderEntries = <HistoryEntry>[];

    for (final entry in entries) {
      final date = entry.timestamp;
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isAtSameMomentAs(today)) {
        todayEntries.add(entry);
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        yesterdayEntries.add(entry);
      } else {
        olderEntries.add(entry);
      }
    }

    if (todayEntries.isNotEmpty) {
      groups.add(_DateGroup('Today', todayEntries));
    }
    if (yesterdayEntries.isNotEmpty) {
      groups.add(_DateGroup('Yesterday', yesterdayEntries));
    }
    if (olderEntries.isNotEmpty) {
      groups.add(_DateGroup('Earlier', olderEntries));
    }

    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<HistoryEntry> entries;

  _DateGroup(this.label, this.entries);
}

class _HistoryItem extends ConsumerWidget {
  final HistoryEntry entry;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelectionToggle;

  const _HistoryItem(
    this.entry, {
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileExists =
        entry.outputPath != null && File(entry.outputPath!).existsSync();

    // In selection mode, disable dismiss
    if (isSelectionMode) {
      return ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => onSelectionToggle(),
        ),
        title: Text(
          entry.sourceFileName ?? 'Unknown File',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: fileExists ? null : TextDecoration.lineThrough,
            color: fileExists ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          '${entry.presetId} • ${entry.format.toUpperCase()}',
          style: TextStyle(color: fileExists ? null : Colors.grey),
        ),
        onTap: onSelectionToggle,
      );
    }

    // Normal mode with dismissible
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(historyProvider.notifier).deleteEntry(entry.id);
      },
      child: ListTile(
        leading: Icon(
          fileExists ? Icons.audio_file : Icons.broken_image,
          color: fileExists ? null : Colors.grey,
        ),
        title: Text(
          entry.sourceFileName ?? 'Unknown File',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: fileExists ? null : TextDecoration.lineThrough,
            color: fileExists ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          '${entry.presetId} • ${entry.format.toUpperCase()}',
          style: TextStyle(color: fileExists ? null : Colors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.folder_open),
          onPressed: fileExists
              ? () {
                  _revealInExplorer(entry.outputPath!);
                }
              : null,
          tooltip: 'Show in Explorer',
        ),
        onTap: () {
          // TODO: Load into editor?
        },
      ),
    );
  }

  Future<void> _revealInExplorer(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
  }
}
