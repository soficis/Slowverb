# Slowverb (Desktop/Mobile)

Cross-platform slowed + reverb editor with VaporXP Luna aesthetic and full parity with the web experience.

**⚠️ Beta Software Notice**  
This software is currently in beta. Not all features may work as expected, and you may encounter bugs or incomplete functionality. Use at your own risk.

## Highlights

- Unified 12-preset catalog (Slowed + Reverb, Vaporwave Chill, Nightcore, Echo Slow, Lo-Fi, Ambient, Deep Bass, Crystal Clear, Underwater, Synthwave, Slow Motion, Manual)
- VaporXP-responsive UI shared with web (design tokens + responsive scaffold)
- Local-only processing with FFmpeg/ffmpeg_kit and real-time preview
- Export to MP3/WAV/AAC with custom save locations
- YouTube audio import and download
- Batch processing for multiple files
- Real-time audio visualizer with shader effects
- History tracking and undo functionality
- Waveform analysis and codec detection

## Develop

```bash
cd app
flutter pub get
flutter run
```

## Build

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

For platform-specific setup (FFmpeg, etc.) see the root README.

## 📜 License

This project is licensed under the **GNU General Public License v3.0** (GPLv3).
