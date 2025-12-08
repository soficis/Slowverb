# Slowverb 🎵

**Create slowed + reverb audio edits with ease**

Slowverb is a cross-platform audio processing application that transforms any song into dreamy, vaporwave-style remixes with  48kHz audio processing, multi-stage reverb, and bass enhancement.

---

## ✨ Features

- **Slowed + Reverb Effect** - Classic dreamy vaporwave sound
- **Professional Audio Quality** - 48kHz sample rate processing
- **Multi-Stage Reverb** - Rich, layered echo effects
- **Bass Enhancement** - Enriched low-end frequencies
- **Real-Time Preview** - Hear changes as you adjust
- **Multiple Export Formats** - MP3, WAV, AAC
- **Custom Save Location** - Choose where to save exports
- **Unified Preset Catalog** - Same 12 presets across web, desktop, and mobile (Slowed + Reverb, Vaporwave Chill, Nightcore, Echo Slow, Lo-Fi, Ambient, Deep Bass, Crystal Clear, Underwater, Synthwave, Slow Motion, Manual)
- **VaporXP Responsive UI** - Shared VaporXP Luna aesthetic with responsive layout on all platforms

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

## FFmpeg Installation

Slowverb requires FFmpeg for audio processing. Choose your platform:

### Windows

#### Option 1: Automatic (Recommended)

```powershell
# Run the setup script
cd app/scripts
.\download_ffmpeg.ps1
```

#### Option 2: Using winget

```powershell
winget install FFmpeg
```

#### Option 3: Using Chocolatey

```powershell
choco install ffmpeg
```

#### Option 4: Manual Download

1. Download from [FFmpeg Builds](https://github.com/BtbN/FFmpeg-Builds/releases)
2. Extract `ffmpeg.exe` to the app directory (next to `slowverb.exe`)

### macOS

#### Using Homebrew (Recommended)

```bash
brew install ffmpeg
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

### Web

```bash
cd web
flutter pub get
flutter build web --release
```

The build output will be in `web/build/web/`. See [Web Version Documentation](./web/README.md) for detailed web deployment and development information.

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows  | ✅ Full Support | Windows 10/11 |
| macOS    | ✅ Full Support | macOS 12+ |
| Linux    | ✅ Full Support | Ubuntu 22.04 |
| Android  | ✅ Full Support | Android 6.0+ |
| iOS      | ✅ Full Support | iOS 12+ |
| Web      | ✅ Full Support | Modern web browsers (Chrome, Firefox, Safari, Edge) |

---

## Web Version

Slowverb includes a **full-featured web version** that runs entirely in the browser with **no server-side processing**. This means:

- ✅ **Complete privacy** - All audio processing happens locally on your device
- ✅ **No audio uploads** - Your files never leave your browser
- ✅ **Instant processing** - No wait times for server processing
- ✅ **Works offline** - After initial load, the app functions without internet connection
- ⚠️ **Browser-dependent** - Audio processing performance depends on your browser's capabilities

### Key Differences from Desktop/Mobile

| Feature | Desktop/Mobile | Web |
|---------|---|---|
| **Audio Engine** | Native FFmpeg | Web Audio API + WASM FFmpeg |
| **Processing** | Fast (native code) | Good (optimized WASM) |
| **File I/O** | Full filesystem access | Browser storage (IndexedDB) |
| **Export** | Direct file save | Browser download |
| **Memory** | System memory | Browser tab memory (~500MB-2GB) |
| **Browser Support** | N/A | Chrome, Firefox, Safari, Edge 15+ |

**Browser Requirements:**
- Chrome 57+ (2017)
- Firefox 52+ (2017)
- Safari 11+ (2017)
- Edge 79+ (Chromium-based)
- Chrome/Firefox on Android

For more details on the web version, see the [Web README](./web/README.md).

---

## Effect Presets

| Preset | Tempo | Pitch | Reverb | Description |
|--------|-------|-------|--------|-------------|
| Slowed + Reverb | 0.7x | -5.1 semi | 40% | Classic dreamy vaporwave |
| Vaporwave Chill | 0.78x | -3 semi | 35% | Warm, nostalgic sound |
| Nightcore | 1.25x | +3 semi | 10% | Fast & energetic |
| Echo Slow | 0.7x | -3 semi | 60% | Hazy with deep echoes |
| Manual | 1.0x | 0 semi | 0% | Full control |

---

## Audio Processing

Slowverb uses professional-grade FFmpeg filters for high-quality audio:

- **48kHz Sample Rate** - Higher than CD quality
- **Multi-Stage Reverb** - 3 echo stages (40/50/70ms)
- **Dynamic Normalization** - Consistent loudness
- **Bass Enhancement** - 5-10dB boost based on reverb

---

## Project Structure

```text
slowverb/
├── app/                    # Flutter application (Mobile + Desktop)
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
├── web/                   # Flutter web application
│   ├── lib/               # Dart source code for web
│   │   ├── app/           # Web app configuration
│   │   ├── domain/        # Shared entities & interfaces
│   │   ├── engine/        # Web audio engine (WASM FFmpeg)
│   │   ├── features/      # Feature modules (web-optimized)
│   │   └── providers/     # State management (Riverpod)
│   ├── web/               # Web assets and HTML
│   │   ├── js/            # JavaScript utilities
│   │   ├── fonts/         # Web fonts
│   │   ├── icons/         # Web app icons
│   │   └── manifest.json  # PWA manifest
│   ├── assets/wasm/       # WASM FFmpeg binaries
│   ├── pubspec.yaml       # Web-specific dependencies
│   └── README.md          # Web version documentation
├── docs/                  # Documentation
├── LICENSE                # GPLv3 License
└── README.md              # This file
```

---

## Acknowledgments

- [Flutter](https://flutter.dev) - Cross-platform framework
- [FFmpeg](https://ffmpeg.org) - Audio processing engine
- [just_audio](https://pub.dev/packages/just_audio) - Audio playback
- [Hive](https://pub.dev/packages/hive) - Local storage

---

## FAQ

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

## 📜 License

This project is licensed under the **GNU General Public License v3.0** (GPLv3) - see the [LICENSE](LICENSE) file for details.

### FFmpeg Attribution & Compliance

This software uses libraries from the [FFmpeg](https://ffmpeg.org) project under the [LGPLv2.1](http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html).

- **FFmpeg Source Code:** The exact source code for the FFmpeg build used in this project can be downloaded from: [Link to your source/fork or upstream if unmodified] (e.g., <https://ffmpeg.org/download.html>)
- **Modifications:** No modifications were made to the FFmpeg source code.
- **Ownership:** This project does NOT own FFmpeg. FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project.

Note: Since this project links to FFmpeg libraries (via dynamic linking or command line execution), and is licensed under GPLv3, it is fully compatible with FFmpeg's licensing terms.
