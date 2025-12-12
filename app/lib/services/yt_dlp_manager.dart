import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Status of yt-dlp tool
enum ToolStatus {
  installed, // Already available
  downloadedNow, // Just downloaded
  downloadFailed, // Failed to download
}

/// Download progress information
class DownloadProgress {
  final double progress; // 0.0 to 1.0, or -1 for indeterminate
  final String message;
  final bool isComplete;
  final bool isError;
  final String? errorMessage;

  const DownloadProgress({
    required this.progress,
    required this.message,
    this.isComplete = false,
    this.isError = false,
    this.errorMessage,
  });

  factory DownloadProgress.indeterminate(String message) =>
      DownloadProgress(progress: -1, message: message);

  factory DownloadProgress.complete(String outputPath) =>
      const DownloadProgress(
        progress: 1.0,
        message: 'Complete',
        isComplete: true,
      );

  factory DownloadProgress.error(String error) => DownloadProgress(
    progress: 0,
    message: error,
    isComplete: true,
    isError: true,
    errorMessage: error,
  );
}

/// Manages yt-dlp installation and usage
class YtDlpManager {
  YtDlpManager();

  Directory? _appSupportDir;
  Directory? _appRoot;

  Future<void> _ensureInitialized() async {
    _appSupportDir ??= await getApplicationSupportDirectory();
    _appRoot ??= Directory.current;
  }

  Directory get _toolsDir => Directory(p.join(_appSupportDir!.path, 'tools'));
  String get _binaryName => Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
  String get _binaryPath => p.join(_toolsDir.path, _binaryName);

  /// Check if yt-dlp is available (tools/ or PATH)
  Future<bool> isAvailable() async {
    await _ensureInitialized();

    // Check tools directory first
    if (await File(_binaryPath).exists()) {
      return true;
    }

    // Check system PATH
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, ['yt-dlp']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Get the path to yt-dlp binary (or null if not available)
  Future<String?> getBinaryPath() async {
    await _ensureInitialized();

    // Check tools directory first
    if (await File(_binaryPath).exists()) {
      return _binaryPath;
    }

    // Check system PATH
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, ['yt-dlp']);
      if (result.exitCode == 0) {
        final pathFromPath = (result.stdout as String).split('\n').first.trim();
        if (pathFromPath.isNotEmpty) {
          return pathFromPath;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Ensure yt-dlp is installed (download if needed)
  Future<ToolStatus> ensureInstalled() async {
    await _ensureInitialized();

    if (await isAvailable()) {
      return ToolStatus.installed;
    }

    // On Android/iOS, we cannot auto-download yt-dlp
    // User needs to install termux or use a different method
    if (Platform.isAndroid || Platform.isIOS) {
      return ToolStatus.downloadFailed;
    }

    // Create tools directory
    if (!await _toolsDir.exists()) {
      await _toolsDir.create(recursive: true);
    }

    // Download yt-dlp directly from GitHub releases
    // This works regardless of whether we're in a bundled app or development
    try {
      final downloadUrl = _getDownloadUrl();
      if (downloadUrl == null) {
        print('YtDlpManager: No download URL for platform');
        return ToolStatus.downloadFailed;
      }

      print('YtDlpManager: Downloading from $downloadUrl');
      print('YtDlpManager: Target path: $_binaryPath');

      // Use http package which handles redirects automatically
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode != 200) {
        print(
          'YtDlpManager: Download failed with status ${response.statusCode}',
        );
        return ToolStatus.downloadFailed;
      }

      print(
        'YtDlpManager: Download complete, ${response.bodyBytes.length} bytes',
      );

      // Write bytes to file
      final file = File(_binaryPath);
      await file.writeAsBytes(response.bodyBytes);

      print('YtDlpManager: File written to $_binaryPath');

      // Make executable on Unix systems
      if (!Platform.isWindows) {
        final chmodResult = await Process.run('chmod', ['+x', _binaryPath]);
        print('YtDlpManager: chmod result: ${chmodResult.exitCode}');

        // Remove macOS quarantine attribute to allow execution
        if (Platform.isMacOS) {
          // Use -c flag to suppress error if attribute doesn't exist
          final xattrResult = await Process.run('xattr', [
            '-d',
            'com.apple.quarantine',
            _binaryPath,
          ]);
          print('YtDlpManager: xattr result: ${xattrResult.exitCode}');
        }
      }

      // Verify the download
      if (await File(_binaryPath).exists()) {
        final stat = await File(_binaryPath).stat();
        print('YtDlpManager: Binary exists, size: ${stat.size}');
        if (stat.size > 1000) {
          // Sanity check - yt-dlp should be several MB
          return ToolStatus.downloadedNow;
        } else {
          print('YtDlpManager: File too small, download may have failed');
          await File(_binaryPath).delete();
        }
      }
    } catch (e, stackTrace) {
      print('YtDlpManager: Download error: $e');
      print('YtDlpManager: Stack trace: $stackTrace');
    }

    return ToolStatus.downloadFailed;
  }

  /// Get the download URL for yt-dlp based on platform
  String? _getDownloadUrl() {
    const baseUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download';
    if (Platform.isWindows) {
      return '$baseUrl/yt-dlp.exe';
    } else if (Platform.isMacOS) {
      return '$baseUrl/yt-dlp_macos';
    } else if (Platform.isLinux) {
      return '$baseUrl/yt-dlp';
    }
    return null;
  }

  /// Start downloading audio from URL using video title as filename
  ///
  /// The [outputDir] should be a directory path. The final filename will be
  /// automatically determined from the video title.
  Future<Process> startDownload({
    required Uri url,
    required String outputDir,
    String audioFormat = 'mp3',
  }) async {
    final binary = await getBinaryPath();
    if (binary == null) {
      throw StateError(
        'yt-dlp is not available. Call ensureInstalled() first.',
      );
    }

    // Use yt-dlp's template to extract video title for filename
    // %(title)s = video title, sanitized for filesystem
    final outputTemplate = p.join(outputDir, '%(title)s.%(ext)s');

    // Find FFmpeg for audio conversion
    final ffmpegPath = await _findFFmpegPath();
    print('YtDlpManager: FFmpeg path: $ffmpegPath');

    // Build arguments
    final args = <String>[
      '-x', // Extract audio only
      '--audio-format', audioFormat,
      '-o', outputTemplate, // Use title template
      '--progress', // Show progress
      '--newline', // Progress on new lines
      '--restrict-filenames', // Safe characters only
      '--print', 'after_move:filepath', // Print final filepath after conversion
    ];

    // Add FFmpeg location if found
    if (ffmpegPath != null) {
      // yt-dlp needs the directory containing ffmpeg, not the executable itself
      final ffmpegDir = p.dirname(ffmpegPath);
      args.addAll(['--ffmpeg-location', ffmpegDir]);
    }

    args.add(url.toString());

    print('YtDlpManager: Running yt-dlp with args: $args');

    // Run yt-dlp with audio extraction
    return Process.start(binary, args);
  }

  /// Find FFmpeg executable path
  Future<String?> _findFFmpegPath() async {
    await _ensureInitialized();

    // Check app's FFmpeg download location first (from FFmpegService)
    final appFFmpegPath = p.join(
      _appSupportDir!.path,
      'ffmpeg',
      'bin',
      'ffmpeg',
    );
    if (await File(appFFmpegPath).exists()) {
      print('YtDlpManager: Found app FFmpeg at $appFFmpegPath');
      return appFFmpegPath;
    }

    // Check system PATH
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, ['ffmpeg']);
      if (result.exitCode == 0) {
        final pathFromPath = (result.stdout as String).split('\n').first.trim();
        if (pathFromPath.isNotEmpty) {
          return pathFromPath;
        }
      }
    } catch (_) {}

    // Check common Homebrew locations on macOS
    if (Platform.isMacOS) {
      const homebrewPaths = [
        '/opt/homebrew/bin/ffmpeg', // Apple Silicon
        '/usr/local/bin/ffmpeg', // Intel
      ];
      for (final path in homebrewPaths) {
        if (await File(path).exists()) {
          return path;
        }
      }
    }

    return null;
  }

  /// Parse yt-dlp progress output
  DownloadProgress parseProgress(String line) {
    // Example: [download]  42.3% of 10.5MiB at 1.2MiB/s ETA 00:07
    final downloadMatch = RegExp(
      r'\[download\]\s+(\d+\.?\d*)%',
    ).firstMatch(line);
    if (downloadMatch != null) {
      final percent = double.parse(downloadMatch.group(1)!) / 100;
      return DownloadProgress(progress: percent, message: 'Downloading...');
    }

    // Example: [ExtractAudio] Destination: output.mp3
    if (line.contains('[ExtractAudio]')) {
      return DownloadProgress.indeterminate('Converting to audio...');
    }

    // Example: [download] Destination: file.webm
    if (line.contains('[download] Destination:')) {
      return DownloadProgress.indeterminate('Starting download...');
    }

    // Default indeterminate
    return DownloadProgress.indeterminate('Processing...');
  }
}
