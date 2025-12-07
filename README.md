# Slowverb 🎵

**Create stunning slowed + reverb audio edits with ease**

Slowverb is a cross-platform audio processing application that transforms any song into dreamy, vaporwave-style remixes. With professional-grade 48kHz audio processing, multi-stage reverb, and bass enhancement, Slowverb delivers studio-quality results.

![Slowverb Preview](docs/preview.png)

---

## ✨ Features

- **Slowed + Reverb Effect** - Classic dreamy vaporwave sound
- **Professional Audio Quality** - 48kHz sample rate processing
- **Multi-Stage Reverb** - Rich, layered echo effects
- **Bass Enhancement** - Enriched low-end frequencies
- **Real-Time Preview** - Hear changes as you adjust
- **Multiple Export Formats** - MP3, WAV, AAC
- **Custom Save Location** - Choose where to save exports
- **Beautiful UI** - Vaporwave-inspired dark theme

---

## 🚀 Quick Start

### Prerequisites

1. **Flutter SDK** (3.0 or higher)
   - [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

2. **FFmpeg** (for audio processing)
   - See [FFmpeg Installation](#ffmpeg-installation) below

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/slowverb.git
cd slowverb

# Navigate to the app directory
cd app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## 📦 FFmpeg Installation

Slowverb requires FFmpeg for audio processing. Choose your platform:

### Windows

**Option 1: Automatic (Recommended)**

```powershell
# Run the setup script
cd app/scripts
.\download_ffmpeg.ps1
```

**Option 2: Using winget**

```powershell
winget install FFmpeg
```

**Option 3: Using Chocolatey**

```powershell
choco install ffmpeg
```

**Option 4: Manual Download**

1. Download from [FFmpeg Builds](https://github.com/BtbN/FFmpeg-Builds/releases)
2. Extract `ffmpeg.exe` to the app directory (next to `slowverb.exe`)

### macOS

**Using Homebrew (Recommended)**

```bash
```

The executable will be at: `build/linux/x64/release/bundle/slowverb`

### Android

```bash
cd app
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
cd app
flutter build ios --release
```

Follow Xcode instructions to archive and deploy.

---

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows  | ✅ Full Support | Tested on Windows 10/11 |
| macOS    | ✅ Full Support | Tested on macOS 12+ |
| Linux    | ✅ Full Support | Tested on Ubuntu 22.04 |
| Android  | ✅ Full Support | Android 6.0+ |
| iOS      | ✅ Full Support | iOS 12+ |

---

## 🎛️ Effect Presets

| Preset | Tempo | Pitch | Reverb | Description |
|--------|-------|-------|--------|-------------|
| Slowed + Reverb | 0.7x | -5.1 semi | 40% | Classic dreamy vaporwave |
| Vaporwave Chill | 0.78x | -3 semi | 35% | Warm, nostalgic sound |
| Nightcore | 1.25x | +3 semi | 10% | Fast & energetic |
| Echo Slow | 0.7x | -3 semi | 60% | Hazy with deep echoes |
| Manual | 1.0x | 0 semi | 0% | Full control |

---

## 🎨 Audio Processing

Slowverb uses professional-grade FFmpeg filters for high-quality audio:

- **48kHz Sample Rate** - Higher than CD quality
- **Multi-Stage Reverb** - 3 echo stages (40/50/70ms)
- **Dynamic Normalization** - Consistent loudness
- **Bass Enhancement** - 5-10dB boost based on reverb

---

## 📁 Project Structure

```
slowverb/
├── app/                    # Flutter application
│   ├── lib/               # Dart source code
│   │   ├── app/           # App configuration
│   │   ├── domain/        # Entities & interfaces
│   │   ├── features/      # Feature modules
│   │   │   ├── editor/    # Audio editor
│   │   │   ├── export/    # Export functionality
│   │   │   └── library/   # Project library
│   │   └── audio_engine/  # FFmpeg integration
│   ├── scripts/           # Build scripts
│   └── test/              # Unit tests
├── docs/                  # Documentation
└── README.md
```

---

## 🛠️ Development

### Running in Development

```bash
cd app
flutter run -d windows  # or macos, linux, chrome
```

### Hot Reload

Press `r` in the terminal while the app is running to hot reload changes.

### Running Tests

```bash
cd app
flutter test
```

### Linting

```bash
cd app
flutter analyze
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - Cross-platform framework
- [FFmpeg](https://ffmpeg.org) - Audio processing engine
- [just_audio](https://pub.dev/packages/just_audio) - Audio playback
- [Hive](https://pub.dev/packages/hive) - Local storage

---

## 📧 Support

If you encounter any issues or have questions:

1. Check the [FAQ](#faq) below
2. Search [existing issues](https://github.com/yourusername/slowverb/issues)
3. Open a [new issue](https://github.com/yourusername/slowverb/issues/new)

---

## ❓ FAQ

**Q: Why do I get "FFmpeg not found" error?**  
A: Install FFmpeg following the [installation instructions](#ffmpeg-installation) above.

**Q: Why is the audio not processed (no reverb)?**  
A: This means FFmpeg is not installed. The app exports the original file as a fallback.

**Q: Can I use my own presets?**  
A: Yes! Select "Manual" preset and adjust the sliders to your liking.

**Q: What audio formats are supported for input?**  
A: MP3, WAV, AAC, FLAC, OGG, and most common audio formats.

**Q: Where are my exported files saved?**  
A: By default, exports go to your Documents/Slowverb folder. You can change this in the Export screen.

---

Made with ❤️ by the Slowverb Team
