# Slowverb Web - Technical Documentation

<p align="center">
  <strong><a href="https://slowverb.vercel.app/">🚀 Live App → https://slowverb.vercel.app/</a></strong>
</p>

---

This document provides in-depth technical details for developers working on or contributing to the Slowverb web application.

> ⚠️ **Tested Browsers**: Google Chrome and Brave. Other browsers may work but are not officially supported.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Technology Stack](#technology-stack)
3. [Audio Engine Deep Dive](#audio-engine-deep-dive)
4. [PhaseLimiter Integration](#phaselimiter-integration)
4. [State Management](#state-management)
5. [Screens and Navigation](#screens-and-navigation)
6. [Visualizers (GPU Shaders)](#visualizers-gpu-shaders)
7. [IndexedDB Persistence](#indexeddb-persistence)
8. [Build and Deployment](#build-and-deployment)
9. [Performance Considerations](#performance-considerations)
10. [Debugging Tips](#debugging-tips)
11. [Release Checklist](#release-checklist)

---

## Quick Start

### Prerequisites

- **Flutter SDK**: 3.22.0+
- **Chrome or Brave browser**

### Development

```bash
# Navigate to web project
cd web

# Install dependencies
flutter pub get

# Run dev server (hot reload enabled)
flutter run -d chrome
```

### Production Build

```bash
flutter build web --wasm --release
# Output: web/build/web/
```

---

## Technology Stack

| Layer              | Technology                    | Purpose                              |
|--------------------|-------------------------------|--------------------------------------|
| **UI Framework**   | Flutter Web (CanvasKit)       | Cross-platform material UI           |
| **State**          | `flutter_riverpod`            | Reactive state management            |
| **Routing**        | `go_router`                   | Declarative URL-based navigation     |
| **Audio DSP**      | FFmpeg.wasm (`@ffmpeg/ffmpeg`)| Tempo, pitch, reverb, encoding       |
| **Audio Playback** | `just_audio` + Web Audio API  | Real-time playback                   |
| **Persistence**    | IndexedDB (`idb_shim`)        | Project storage                      |
| **Visualizers**    | GLSL Fragment Shaders         | GPU-accelerated audio visualization  |
| **Animations**     | `flutter_animate`             | Micro-interactions                   |

---

## Audio Engine Deep Dive

### Overview

The audio engine is implemented in `lib/engine/wasm_audio_engine.dart`. It communicates with a **Web Worker** (`web/js/audio_worker.js`) that runs FFmpeg.wasm in a background thread.

### Message Flow

```
┌────────────────────┐          ┌────────────────────┐
│  Dart (UI Thread)  │  ─────►  │  Web Worker        │
│  WasmAudioEngine   │  JS      │  audio_worker.js   │
│                    │  Interop │                    │
│                    │  ◄─────  │  FFmpeg.wasm       │
└────────────────────┘          └────────────────────┘
```

1. **Dart → JS**: Uses `dart:js_interop` to call functions exposed by `slowverb_bridge.js`.
2. **JS → Worker**: `slowverb_bridge.js` sends messages to the Web Worker.
3. **Worker → FFmpeg**: The worker loads `@ffmpeg/ffmpeg` and executes FFmpeg commands.
4. **Result**: The processed audio buffer is sent back to Dart via `postMessage`.

### Key Methods

| Method               | Description                                                       |
|----------------------|-------------------------------------------------------------------|
| `initialize()`       | Sets up progress and log handlers.                                |
| `loadSource()`       | Loads a file into memory, probes metadata (duration, sample rate).|
| `getWaveform()`      | Extracts waveform amplitude data for visualization.               |
| `renderPreview()`    | Renders a short preview (30 seconds) for playback.                |
| `startRender()`      | Starts a full render job (non-blocking, returns `RenderJobId`).   |
| `watchProgress()`    | Returns a `Stream<RenderProgress>` for tracking export progress.  |
| `getResult()`        | Retrieves the final rendered bytes after completion.              |
| `cancelRender()`     | Aborts an in-progress render.                                     |
| `renderBatch()`      | Processes multiple files sequentially (up to 50).                 |

### DSP Specification

Effect parameters are converted to a **DSP spec object** and sent to the worker:

```dart
Map<String, Object?> _toDspSpec(EffectConfig config) {
  return {
    'specVersion': '1.0.0',
    'tempo': config.tempo,           // 0.5 – 2.0
    'pitch': config.pitchSemitones,  // -12 – +12
    'eqWarmth': config.eqWarmth,     // 0.0 – 1.0
    'reverb': {
      'decay': config.reverbAmount,
      'preDelayMs': 30,
      'roomScale': 0.7,
    },
    'echo': {
      'delayMs': 500 * config.echoAmount,
      'feedback': config.echoAmount * 0.6,
    },
  };
}
```

The worker translates this spec into FFmpeg filter arguments.

---

## PhaseLimiter Integration

Professional mastering is implemented as an alternate pipeline that runs a WebAssembly build of the PhaseLimiter engine in a dedicated worker. It is triggered when `mastering.algorithm === "phaselimiter"` in the DSP spec.

### Architecture

```
Upload → FFmpeg Worker (decode) → Float32 PCM → PhaseLimiter Worker (2‑pass) → PCM → FFmpeg Worker (encode) → Download
```

- Two‑pass algorithm (analysis then processing) requires full‑buffer PCM, not streaming.
- Single‑threaded WASM (TBB disabled) for maximum browser compatibility.
- Uses Transferable buffers to avoid copies between main thread and workers.

### Key files and paths

- Dart UI/engine
  - `lib/engine/wasm_audio_engine.dart` – emits mastering config and algorithm
  - `lib/features/editor/…` – UI toggle; desktop + mobile layouts
  - `lib/features/export/export_screen.dart` – shows decoding/mastering/encoding stage text
  - `lib/services/phase_limiter_service.dart` – worker wrapper (progress + Transferables)
- TypeScript core
  - `packages/shared/src/protocol.ts` – protocol includes `mastering` + `algorithm`
  - `packages/core/src/engine.ts` – routes mastering to the right path
  - `packages/core-worker/src/worker.ts` – switches pipeline (simple | phaselimiter)
- Worker + WASM
  - `web/js/phase_limiter_worker.js` – dedicated worker that loads `phaselimiter.js`
  - `web/js/phaselimiter.{js,wasm}` – generated artifacts (see wasm build below)
  - Test harness: `web/phaselimiter_test.html`

### Building the WASM module

Artifacts are generated from the adapter in `wasm/phaselimiter` and copied to `web/web/js/`.

On Windows (PowerShell):

```powershell
cd ..\wasm\phaselimiter
./build.ps1
```

On macOS/Linux (bash):

```bash
cd ../wasm/phaselimiter
./build.sh
```

Outputs:

- `web/web/js/phaselimiter.js`
- `web/web/js/phaselimiter.wasm`

See `wasm/phaselimiter/README.md` for prerequisites and troubleshooting.

### Running the browser harness

```bash
cd web
flutter run -d chrome --web-port=8080
# Open http://localhost:8080/phaselimiter_test.html
```

### Developer workflow

1. Adjust UI/engine (`lib/engine/wasm_audio_engine.dart`) to emit `mastering: { enabled, algorithm }`.
2. Ensure TS protocol and core worker consume `mastering.algorithm` and switch pipelines.
3. Build TS bundles:

```bash
cd web
npm run build         # or: npm run build:ts
```

4. Build WASM artifacts if the adapter changes (see above).
5. Verify end‑to‑end in the app and with the harness page.

### Progress & stages

- Worker posts `{ stage: 'decoding' | 'mastering' | 'encoding', percent }` updates.
- Export UI renders stage text and percentage via existing progress stream.

### Constraints & tips

- Memory: a 3–5 minute stereo 44.1kHz float track can reach ~350–400MB total transient usage across buffers; favor Transferables.
- Mobile: consider gating long files (e.g., >5 minutes) to avoid OOM (see `PhaseLimiterService`).
- Performance: single‑threaded MVP targets ~20–40s for a 3‑min song; ensure clear progress UI.

---

## State Management

Slowverb uses **Riverpod** for state management. Key providers are in `lib/providers/`:

### `audio_editor_provider.dart`

- `audioEditorProvider`: Main editor state (loaded file, metadata, effect config).
- `AudioEditorNotifier`: Methods like `importFile()`, `setPreset()`, `updateEffect()`, `renderPreview()`.

### `audio_playback_provider.dart`

- `audioPlaybackProvider`: Playback state (playing, paused, position).
- `AudioPlaybackNotifier`: Controls the `just_audio` player.

### `audio_engine_provider.dart`

- `audioEngineProvider`: Singleton `WasmAudioEngine` instance.

### `project_repository_provider.dart`

- `projectsProvider`: Async list of all saved projects.
- `projectRepositoryProvider`: CRUD operations for projects in IndexedDB.

---

## Screens and Navigation

Navigation is handled by `go_router` in `lib/app/router.dart`:

| Route       | Screen             | Description                        |
|-------------|--------------------|------------------------------------|
| `/`         | `ImportScreen`     | File picker, drop zone.            |
| `/editor`   | `EditorScreen`     | Main editor with waveform, controls.|
| `/export`   | `ExportScreen`     | Format selection, render progress. |
| `/library`  | `LibraryScreen`    | Saved projects list.               |
| `/settings` | `SettingsScreen`   | App version, usage guidelines.     |
| `/about`    | `AboutScreen`      | Credits, features, license info.   |

### Editor Screen Layout

The `EditorScreen` adapts to screen size:

- **Wide layout (>1000px)**: Side-by-side panels (visualizer + controls).
- **Stacked layout (<1000px)**: Vertically stacked panels for mobile/tablet.

---

## Visualizers (GPU Shaders)

Visualizers are implemented as **GLSL fragment shaders** in `web/shaders/`:

| File               | Visualizer          |
|--------------------|---------------------|
| `pipes_3d.frag`    | 3D Pipes            |
| `starfield.frag`   | Starfield Warp      |
| `maze_3d.frag`     | Neon Maze           |
| `wmp_retro.frag`   | WMP Retro Bars      |

### Audio Analysis

The `VisualizerPanel` widget (`lib/features/visualizer/visualizer_panel.dart`) connects audio analysis data to the shader:

- **RMS (Volume)**: Overall loudness.
- **Bass/Mid/Treble**: Frequency band energies.
- **Time**: Current playback position.

These values are passed as shader uniforms to drive the animation.

---

## IndexedDB Persistence

Projects are stored in IndexedDB via `idb_shim`:

### Stored Data

```dart
class Project {
  String id;
  String name;
  String? sourceFileName;
  int durationMs;
  String presetId;
  Map<String, double> parameters;
  DateTime createdAt;
  DateTime? updatedAt;
  String? lastExportFormat;
  DateTime? lastExportDate;
}
```

### File System Access API

On supported browsers (Chrome, Edge), Slowverb uses the **File System Access API** to store file handles. This allows reopening a file without the user re-selecting it.

If the handle is invalid (e.g., user moved the file), the Library screen shows a dialog prompting the user to re-select the file.

---

## Build and Deployment

### Development Build

```bash
flutter run -d chrome
```

Starts a dev server at `http://localhost:PORT` with hot reload.

### Production Build

```bash
flutter build web --wasm --release
```

- Output: `web/build/web/`
- Size: ~5-10 MB gzipped (includes FFmpeg.wasm ~30MB uncompressed).

### Deployment Options

| Platform        | Instructions                                    |
|-----------------|-------------------------------------------------|
| **Vercel**      | Connect GitHub repo, auto-deploys on push.      |
| **Netlify**     | Drag-and-drop `build/web/` or connect repo.     |
| **GitHub Pages**| Deploy `build/web/` to `gh-pages` branch.       |
| **Firebase**    | `firebase deploy --only hosting`.               |

### CORS Headers

If hosting FFmpeg.wasm on a separate CDN, ensure:

```
Access-Control-Allow-Origin: *
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

---

## Performance Considerations

### Memory Limits

- Browser tabs typically have 500MB–2GB memory.
- Files over ~100MB may cause slowdowns.
- Files over 200MB are blocked with an error message.

### Processing Time

- A 3-minute song typically processes in 30-60 seconds.
- Longer songs scale linearly.

### Optimization Tips

- Use **Web Workers** (already implemented) to keep UI responsive.
- **Chunk processing** for very large files (not yet implemented).
- Enable **gzip compression** on your hosting provider (~80% size reduction).

---

## Debugging Tips

### Browser DevTools

- **Console**: Watch for `[WasmAudioEngine]` and `[audio_worker]` logs.
- **Network**: Verify FFmpeg.wasm and core files are loading.
- **Application > IndexedDB**: Inspect saved projects.
- **Performance**: Profile rendering bottlenecks.

### Common Issues

| Issue                          | Solution                                              |
|--------------------------------|-------------------------------------------------------|
| "FFmpeg not available"         | Check Network tab for failed WASM downloads.          |
| "Out of memory"                | Reduce file size or close other tabs.                 |
| "Playback not working on iOS"  | iOS requires user gesture to enable audio.            |
| "Render job not found"         | Ensure `startRender` completes before `watchProgress`.|

---

## Release Checklist

Before deploying to production:

- [ ] Run `flutter clean && flutter pub get`
- [ ] Run `flutter analyze` (no errors)
- [ ] Run `flutter test` (if tests exist)
- [ ] Build: `flutter build web --wasm --release`
- [ ] Test in Chrome and Brave
- [ ] Test on mobile browser (Android Chrome)
- [ ] Verify FFmpeg.wasm loads correctly
- [ ] Check IndexedDB persistence
- [ ] Update version in `lib/app/app_config.dart`

---

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [FFmpeg.wasm Documentation](https://github.com/ffmpegwasm/ffmpeg.wasm)
- [Riverpod Documentation](https://riverpod.dev)
- [Web Audio API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPLv3).

### PhaseLimiter Attribution

Slowverb’s professional mastering path integrates the MIT‑licensed PhaseLimiter engine:

```
PhaseLimiter - MIT License
Copyright (c) 2023 Shin Fukuse
https://github.com/ai-mastering/phaselimiter
```

---

<p align="center">
  <strong><a href="https://slowverb.vercel.app/">🚀 Try Slowverb Live → https://slowverb.vercel.app/</a></strong>
</p>
