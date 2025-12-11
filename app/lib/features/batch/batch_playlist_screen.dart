import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:slowverb/app/colors.dart';
import 'package:slowverb/app/router.dart';
import 'package:slowverb/domain/entities/batch_job.dart';
import 'package:slowverb/domain/entities/render_job.dart';
import 'package:slowverb/features/batch/batch_processor.dart';

class BatchPlaylistScreen extends ConsumerStatefulWidget {
  const BatchPlaylistScreen({super.key});

  @override
  ConsumerState<BatchPlaylistScreen> createState() =>
      _BatchPlaylistScreenState();
}

class _BatchPlaylistScreenState extends ConsumerState<BatchPlaylistScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<String> _loadedPaths = [];
  String? _appStoragePath;

  @override
  void initState() {
    super.initState();
    _loadAppStoragePath();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAppStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    setState(() => _appStoragePath = dir.path);
  }

  Future<void> _syncPlaylist(BatchJob? batch) async {
    final paths = batch == null
        ? <String>[]
        : batch.items
              .where((item) => item.status == RenderJobStatus.success)
              .map((item) => item.outputPath)
              .whereType<String>()
              .where((p) => File(p).existsSync())
              .toList();

    if (_samePaths(paths)) return;

    if (paths.isEmpty) {
      await _player.stop();
      setState(() => _loadedPaths = []);
      return;
    }

    final sources = paths
        .map((p) => AudioSource.uri(Uri.file(p), tag: p))
        .toList();

    await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
    setState(() => _loadedPaths = paths);
  }

  bool _samePaths(List<String> next) {
    if (next.length != _loadedPaths.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i] != _loadedPaths[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final batch = ref.watch(batchProcessorProvider);

    // Keep playlist in sync with current batch outputs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPlaylist(batch);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Playlist'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: SlowverbColors.backgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outputs saved to:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _lastOutputDir(batch) ?? _appStoragePath ?? 'Unknown',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _buildControls(),
              const SizedBox(height: 16),
              Expanded(child: _buildPlaylist()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processing = state?.processingState;
        final canPlay = _loadedPaths.isNotEmpty;

        return Row(
          children: [
            IconButton(
              onPressed: canPlay ? _player.seekToPrevious : null,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              onPressed: canPlay
                  ? () async {
                      if (playing) {
                        await _player.pause();
                      } else {
                        await _player.play();
                      }
                    }
                  : null,
              icon: Icon(
                playing && processing != ProcessingState.completed
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
            IconButton(
              onPressed: canPlay ? _player.seekToNext : null,
              icon: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 12),
            Text(
              _loadedPaths.isEmpty
                  ? 'No processed files'
                  : '${_loadedPaths.length} tracks',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaylist() {
    if (_loadedPaths.isEmpty) {
      return const Center(
        child: Text(
          'No processed tracks found yet. Run a batch export first.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snapshot) {
        final current = snapshot.data ?? -1;
        return ListView.builder(
          itemCount: _loadedPaths.length,
          itemBuilder: (context, index) {
            final path = _loadedPaths[index];
            final isActive = index == current;
            return ListTile(
              leading: Icon(
                isActive ? Icons.equalizer : Icons.music_note,
                color: isActive ? SlowverbColors.neonCyan : Colors.white70,
              ),
              title: Text(p.basename(path), overflow: TextOverflow.ellipsis),
              subtitle: Text(
                p.dirname(path),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              onTap: () async {
                await _player.seek(Duration.zero, index: index);
                await _player.play();
              },
            );
          },
        );
      },
    );
  }

  String? _lastOutputDir(BatchJob? batch) {
    final outputs =
        batch?.items
            .where((item) => item.status == RenderJobStatus.success)
            .map((item) => item.outputPath)
            .whereType<String>()
            .where((p) => p.isNotEmpty)
            .toList() ??
        <String>[];
    if (outputs.isEmpty) return null;
    final output = outputs.last;
    return p.dirname(output);
  }
}
