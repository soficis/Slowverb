import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slowverb/services/yt_dlp_manager.dart';

final ytDlpManagerProvider = Provider((ref) => YtDlpManager());

class YouTubeImportDialog extends ConsumerStatefulWidget {
  const YouTubeImportDialog({super.key});

  @override
  ConsumerState<YouTubeImportDialog> createState() =>
      _YouTubeImportDialogState();
}

class _YouTubeImportDialogState extends ConsumerState<YouTubeImportDialog> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  DownloadProgress? _progress;
  String? _downloadedFile;
  bool _isValidUrl = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validateUrl);
  }

  void _validateUrl() {
    final urlText = _urlController.text.trim();
    if (urlText.isEmpty) {
      if (_isValidUrl) {
        setState(() => _isValidUrl = false);
      }
      return;
    }

    final url = Uri.tryParse(urlText);
    final isValid =
        url != null &&
        (url.host.contains('youtube.com') || url.host.contains('youtu.be'));

    if (isValid != _isValidUrl) {
      setState(() => _isValidUrl = isValid);
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_validateUrl);
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from YouTube'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legal notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only download content you have permission to use.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // URL input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: Icon(Icons.link),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Progress indicator
            if (_isLoading && _progress != null) ...[
              LinearProgressIndicator(
                value: _progress!.progress >= 0 ? _progress!.progress : null,
              ),
              const SizedBox(height: 8),
              Text(
                _progress!.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading || !_isValidUrl ? null : _handleImport,
          child: const Text('Download'),
        ),
      ],
    );
  }

  Future<void> _handleImport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _progress = null;
    });

    try {
      final ytDlp = ref.read(ytDlpManagerProvider);

      // Check if yt-dlp is available
      final status = await ytDlp.ensureInstalled();

      if (status == ToolStatus.downloadFailed) {
        setState(() {
          _error = Platform.isAndroid || Platform.isIOS
              ? 'YouTube import is not available on mobile devices. '
                    'Please use the file import feature instead.'
              : 'Failed to download yt-dlp tool. Please try again.';
          _isLoading = false;
        });
        return;
      }

      if (status == ToolStatus.downloadedNow && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('yt-dlp downloaded successfully')),
        );
      }

      // Parse URL
      final urlText = _urlController.text.trim();
      final url = Uri.tryParse(urlText);
      if (url == null ||
          !url.host.contains('youtube.com') && !url.host.contains('youtu.be')) {
        setState(() {
          _error = 'Invalid YouTube URL';
          _isLoading = false;
        });
        return;
      }

      // Setup output path
      final tempDir = await getTemporaryDirectory();

      // Start download - yt-dlp will use video title as filename
      final process = await ytDlp.startDownload(
        url: url,
        outputDir: tempDir.path,
        audioFormat: 'mp3',
      );

      String? actualFilename;

      // Listen to stdout to capture the actual filename
      process.stdout.listen((data) {
        final output = String.fromCharCodes(data);

        // Process each line separately (yt-dlp outputs multiple lines)
        for (final line in output.split('\n')) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          // Check for filepath output from --print after_move:filepath
          // This will be is a clean line containing the final mp3 path
          if (trimmedLine.endsWith('.mp3') &&
              (trimmedLine.contains('/') || trimmedLine.contains('\\'))) {
            actualFilename = trimmedLine;
            print('Captured downloaded file: $actualFilename');
          }

          // Also parse progress
          final progress = ytDlp.parseProgress(trimmedLine);
          if (mounted) {
            setState(() => _progress = progress);
          }
        }
      });

      process.stderr.listen((data) {
        final line = String.fromCharCodes(data);
        print('yt-dlp error: $line');
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        // Use the actual filename captured from stdout
        if (actualFilename != null && await File(actualFilename!).exists()) {
          if (mounted) {
            setState(() {
              _downloadedFile = actualFilename;
              _isLoading = false;
              _progress = DownloadProgress.complete(_downloadedFile!);
            });

            // Close dialog and return file path
            Navigator.pop(context, _downloadedFile);
          }
        } else {
          // Fallback: search for most recent mp3 if filename wasn't captured
          final files = tempDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.mp3'))
              .toList();

          // Sort by modification time to get most recent
          files.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

          if (files.isNotEmpty && mounted) {
            setState(() {
              _downloadedFile = files.first.path;
              _isLoading = false;
              _progress = DownloadProgress.complete(_downloadedFile!);
            });

            // Close dialog and return file path
            Navigator.pop(context, _downloadedFile);
          } else {
            setState(() {
              _error = 'Download completed but file not found';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _error = 'Download failed (exit code: $exitCode)';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }
}
