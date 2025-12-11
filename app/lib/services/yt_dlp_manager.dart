import 'dart:io';

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

    // Find setup script
    final scriptsDir = Directory(p.join(_appRoot!.path, 'scripts'));
    final scriptPath = p.join(
      scriptsDir.path,
      Platform.isWindows ? 'setup_yt_dlp.ps1' : 'setup_yt_dlp.sh',
    );

    if (!await File(scriptPath).exists()) {
      // Script missing - can't auto-download
      return ToolStatus.downloadFailed;
    }

    // Run setup script
    ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run('powershell', [
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-TargetDir',
        _toolsDir.path,
      ]);
    } else {
      result = await Process.run('bash', [scriptPath, _toolsDir.path]);
    }

    // Check if download succeeded
    if (result.exitCode == 0 && await File(_binaryPath).exists()) {
      return ToolStatus.downloadedNow;
    }

    return ToolStatus.downloadFailed;
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

    // Run yt-dlp with audio extraction
    return Process.start(binary, [
      '-x', // Extract audio only
      '--audio-format', audioFormat,
      '-o', outputTemplate, // Use title template
      '--progress', // Show progress
      '--newline', // Progress on new lines
      '--restrict-filenames', // Safe characters only
      '--print', 'after_move:filepath', // Print final filepath after conversion
      url.toString(),
    ]);
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
