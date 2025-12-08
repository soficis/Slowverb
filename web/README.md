# Slowverb Web - Browser-Based Slowed + Reverb Editor

**Run Slowverb entirely in your browser with zero server-side processing**

This is the web version of Slowverb, a Flutter web application that brings all the audio editing capabilities to modern web browsers. All audio processing happens locally on the user's device—no files are ever uploaded to a server.

## 🎯 Features

- ✅ **Complete Local Processing** - All reverb, tempo, and pitch processing occurs in the browser
- ✅ **Privacy-First** - Audio files never leave your device
- ✅ **No Server Required** - Deploy as a static site
- ✅ **Works Offline** - Fully functional after initial load
- ✅ **WASM-Powered** - Uses WebAssembly FFmpeg for high-performance audio processing
- ✅ **PWA Support** - Install as a web app on any device
- ✅ **IndexedDB Storage** - Browser-based file persistence

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** (3.9.2+)
- **Web browser** with WebAssembly support (Chrome 57+, Firefox 52+, Safari 11+, Edge 79+)

### Development

```bash
# Clone and navigate to the web directory
cd web

# Install dependencies
flutter pub get

# Run development server (hot reload enabled)
flutter run -d chrome
```

### Production Build

```bash
cd web

# Build for production
flutter build web --release

# Output location: build/web/
```

## 📁 Project Structure

```text
web/
├── lib/
│   ├── main.dart                  # Web app entry point
│   ├── app/
│   │   ├── app.dart              # App widget & routing
│   │   └── routes.dart           # Go Router configuration
│   ├── domain/
│   │   ├── entities/             # Audio data models
│   │   └── repositories/         # Abstract repository interfaces
│   ├── engine/
│   │   ├── wasm_engine.dart      # WASM FFmpeg wrapper
│   │   ├── audio_processor.dart  # Audio processing logic
│   │   └── worker/               # Web Worker integration
│   ├── features/
│   │   ├── editor/               # Audio editing UI
│   │   │   ├── views/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   └── export/               # Export functionality
│   └── providers/                # Riverpod state management
│       ├── audio_provider.dart
│       ├── export_provider.dart
│       └── storage_provider.dart
├── web/
│   ├── index.html               # Entry HTML file
│   ├── manifest.json            # PWA manifest
│   ├── js/
│   │   └── wasm_loader.js       # WASM initialization
│   ├── fonts/                   # Web fonts
│   ├── icons/                   # PWA icons
│   └── favicon.png
├── assets/
│   └── wasm/                    # WebAssembly binaries
│       ├── ffmpeg.wasm
│       └── ffmpeg.worker.js
├── test/
│   └── widget_test.dart
└── pubspec.yaml
```

## 🔧 Technology Stack

### Core Framework
- **Flutter Web** - UI framework compiled to HTML/CSS/JavaScript
- **Dart** - Programming language for Flutter

### Audio Processing
- **FFmpeg.wasm** - WebAssembly-compiled FFmpeg for audio processing
- **Web Audio API** - Browser's native audio playback
- **just_audio** - Flutter audio plugin (web-compatible)

### State Management & Storage
- **Riverpod** - Reactive state management
- **IndexedDB** - Browser database via `idb_shim`
- **File Picker** - Cross-platform file selection

### Routing & Navigation
- **Go Router** - URL-based navigation

### Development
- **build_runner** - Code generation for Riverpod
- **flutter_lints** - Code style enforcement

## 🎛️ Audio Engine Architecture

### Web Audio Processing Pipeline

The web version uses a hybrid architecture for audio processing:

1. **WASM FFmpeg Engine** - Runs FFmpeg compiled to WebAssembly
   - Handles tempo shifting (0.5x - 2.0x)
   - Pitch shifting (-12 to +12 semitones)
   - Reverb effect (40ms, 50ms, 70ms delays)
   - Normalization and bass enhancement
   - Supports: MP3, WAV, AAC, FLAC, OGG

2. **Web Audio API** - Native browser audio
   - Playback and real-time preview
   - Latency-optimized processing
   - Hardware acceleration support

3. **Web Workers** - Background processing
   - Offloads heavy computation to prevent UI blocking
   - Parallel processing of audio chunks

### Memory & Performance

- **Chunk Processing** - Audio is processed in manageable chunks to prevent memory overflow
- **Memory Limit** - Browser tab typically has 500MB-2GB available (varies by browser)
- **File Size Limit** - Practical limit ~500MB before processing becomes slow
- **Processing Time** - Scales with audio length; typical 3-5min songs process in 30-60 seconds

### Browser Compatibility

| Browser | Version | WebAssembly | Web Audio API | IndexedDB | Status |
|---------|---------|---|---|---|---|
| Chrome | 57+ | ✅ | ✅ | ✅ | ✅ Full Support |
| Firefox | 52+ | ✅ | ✅ | ✅ | ✅ Full Support |
| Safari | 11+ | ✅ | ✅ | ✅ | ✅ Full Support |
| Edge | 79+ | ✅ | ✅ | ✅ | ✅ Full Support |
| Android Chrome | Latest | ✅ | ✅ | ✅ | ✅ Full Support |
| iOS Safari | 12+ | ✅ | ⚠️ | ✅ | ⚠️ Limited (no playback in background) |

**Note:** iOS Safari has restrictions on background audio and may require user interaction to enable audio processing.

## 📦 Build & Deployment

### Local Development Build

```bash
flutter run -d chrome
```

This starts a development server (default: http://localhost:8080) with hot reload support.

### Production Build

```bash
flutter build web --release
```

**Build Artifacts:**
- `build/web/` - Complete web application
- Size: ~5-10MB gzipped (includes WASM FFmpeg)
- All assets are self-contained for static hosting

### Deployment Options

#### 1. Static Hosting (Recommended)
Deploy to any static hosting service:
- **GitHub Pages** - Free, built-in CI/CD
- **Netlify** - Automatic builds from git
- **Vercel** - Fast CDN, instant deployments
- **Firebase Hosting** - Serverless, great DX
- **AWS S3 + CloudFront** - Enterprise-grade

Example GitHub Pages deployment:
```bash
flutter build web --release
# Deploy build/web/ directory to GitHub Pages
```

#### 2. Docker Container
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY build/web/ .
RUN npm install -g http-server
EXPOSE 8080
CMD ["http-server", "-p", "8080", "-c-1"]
```

#### 3. Traditional Web Server
```bash
# Copy build/web/ to your web server
# Configure to serve index.html for all routes (SPA routing)
```

### Cross-Origin Resource Sharing (CORS)

The web app requires CORS headers if assets are served from a different domain:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, OPTIONS
```

Most CDNs handle this automatically.

## 🔄 State Management with Riverpod

This project uses **Riverpod** for state management. Key providers:

### Audio Providers
- `audioFileProvider` - Current loaded audio file
- `audioProcessingStateProvider` - Processing status (idle, processing, complete)
- `presetProvider` - Active effect preset

### Processing Providers
- `tempoProvider` - Tempo multiplier (0.5 - 2.0)
- `pitchProvider` - Pitch shift amount (-12 to +12)
- `reverbProvider` - Reverb intensity (0 - 100%)

### Storage Providers
- `projectsProvider` - Persisted project list
- `localStorageProvider` - IndexedDB access

See `lib/providers/` for implementation details.

## 💾 Local Storage

The web version uses **IndexedDB** for persistence:

### Stored Data
- Recent projects (file metadata, processing settings)
- User preferences (theme, default export format)
- Processing cache (for faster re-processing of similar files)

### Storage Quota
- Typical: 50MB-1GB (browser-dependent)
- Chrome: ~50MB by default
- Firefox: Up to browser's available space
- Safari: ~50MB per site

### Clearing Storage
Users can clear storage via browser DevTools or through the app's settings menu.

## 🐛 Development & Debugging

### Debug Build

```bash
flutter run -d chrome
```

Then open Chrome DevTools (F12) to debug:
- **Console** - JavaScript errors and logs
- **Sources** - Debug Dart code via source maps
- **Network** - Monitor WASM/asset loading
- **Storage** - Inspect IndexedDB

### Common Issues

**"FFmpeg not available"**
- Check that WASM files are loaded in DevTools Network tab
- Verify `assets/wasm/` is included in build

**"Out of memory"**
- Reduce file size or split processing
- Close other browser tabs to free memory

**"Playback not working on iOS"**
- iOS requires user gesture to enable audio
- Ensure button tap initiates playback

## 📊 Performance Optimization

### Build Optimization
```bash
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://cdn.example.com/
```

### Compression
- Gzip compression: ~80% size reduction
- Enable in web server configuration

### Caching Strategy
- Static assets: Long-term cache (1 year)
- index.html: No cache (get latest on reload)
- WASM files: Long-term cache

### Code Splitting
- Flutter web automatically splits code by route
- WASM FFmpeg is lazy-loaded on first use

## 🚢 Release Checklist

Before pushing to production:

- [ ] Run `flutter clean && flutter pub get`
- [ ] Run all tests: `flutter test`
- [ ] Build release: `flutter build web --release`
- [ ] Test in multiple browsers (Chrome, Firefox, Safari, Edge)
- [ ] Test on mobile browsers
- [ ] Verify WASM assets load correctly
- [ ] Check performance with DevTools
- [ ] Update version in `pubspec.yaml`
- [ ] Test offline functionality
- [ ] Verify PWA manifest and icons

## 📚 Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [FFmpeg.wasm Documentation](https://github.com/ffmpegwasm/ffmpeg.wasm)
- [Riverpod Documentation](https://riverpod.dev)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [WebAssembly Docs](https://webassembly.org/)

## 🔗 Links

- **Main Repository**: [GitHub](https://github.com/soficis/slowverb)
- **Main README**: See [README.md](../README.md) for desktop/mobile information
- **Issue Tracker**: [GitHub Issues](https://github.com/soficis/slowverb/issues)

