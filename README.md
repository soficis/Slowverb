<h1 align="center"><b>Slowverb 🎵</b></h1>

<p align="center">
  <strong><a href="https://slowverb.vercel.app/">🚀 Try Slowverb Live → https://slowverb.vercel.app/</a></strong>
</p>

---

**Slowverb** is a web-based audio editor for creating **slowed + reverb**, **vaporwave**, and other dreamy audio effects. It runs entirely in your browser—no installation or server uploads required. All audio processing happens on your machine using WebAssembly (WASM) technology.

> ⚠️ **Browser Compatibility**: This application has been tested on **Google Chrome**. Other browsers (Firefox, Safari, Edge) may work but are not officially supported.

---

## Table of Contents

1. [What is Slowverb?](#what-is-slowverb)
2. [Key Features](#key-features)
3. [How It Works](#how-it-works)
4. [Getting Started (Users)](#getting-started-users)
5. [Effect Presets](#effect-presets)
6. [Visualizers](#visualizers)
7. [Export Formats](#export-formats)
8. [Project Library](#project-library)
9. [Technical Architecture](#technical-architecture)
10. [Developer Setup](#developer-setup)
11. [Project Structure](#project-structure)
12. [License](#license)

---

## What is Slowverb?

Slowverb takes any audio file and applies a combination of effects to transform it:

- **Slowing down** the tempo (speed).
- **Shifting the pitch** (higher or lower).
- **Adding reverb** (echo/room ambiance).
- **Applying EQ warmth** (bass boost/lo-fi character).

The result is the signature "slowed + reverb" sound popular in vaporwave, lo-fi hip hop, and chillwave music.

### Why Local Processing?

Slowverb uses **FFmpeg.wasm**, a WebAssembly port of the industry-standard FFmpeg audio tool. This means:

- Your audio files are processed directly in the browser.
- No need for a backend server to handle audio encoding.
- Faster response times since there's no network upload/download.

---

## Key Features

### 🎚️ Real-Time Effect Controls

The editor screen provides interactive sliders for:

| Parameter     | Range            | Description                                      |
|---------------|------------------|--------------------------------------------------|
| **Tempo**     | 0.5x – 2.0x      | Slow down or speed up the audio.                 |
| **Pitch**     | -12 to +12 semi  | Lower or raise the pitch.                        |
| **Reverb**    | 0% – 100%        | Add room echo and decay.                         |
| **Echo**      | 0% – 100%        | Add a repeating echo effect.                     |
| **EQ Warmth** | 0% – 100%        | Boost low frequencies for a warmer, lo-fi sound. |
| **Phaser Speed** | 0.1 – 5.0 Hz  | Rate of phaser modulation                        |
| **Phaser Depth** | 0 – 100%     | Amount of phaser effect                          |
| **Bass Boost** | -20 to +20 dB   | Bass shelf boost/cut at 100Hz                    |

### ✨ High-Quality (HQ) Audio Engine

Slowverb now defaults to high-quality processing for all presets:

- **HQ Slowed (SoundTouch)**: Uses the industry-standard SoundTouch algorithm for time-stretching. This prevents the "phasing" or "metallic" artifacts common in basic slowdowns, resulting in a cleaner, more natural sound even at extreme speeds.
- **HQ Reverb (Tone)**: Utilizes an advanced reverb engine with configurable room scale, damping, and stereo width. It provides a much denser and more immersive atmosphere than standard algorithmic reverbs. Recent tuning has refined the gain staging (up to +42dB compensation) and echo feedback to eliminate unwanted percussion artifacts.
- **Freeverb IR (SoX-matched)**: A pure JavaScript implementation of SoX’s Freeverb algorithm (8 parallel comb filters + 4 serial allpass filters) that generates impulse responses matching classical acoustic spatial reverb. Selected when quality.reverb = freeverb.
- **HQ Enabled by Default**: All built-in presets leverage these HQ features for a professional, consistent audio experience.

### 📊 Waveform Display

The waveform panel shows a visual representation of your audio file. You can click anywhere on the waveform to seek to that position in the track.

### 🎧 Preview Mode

Before exporting, you can generate a **real-time preview** of your processed audio. The editor displays live progress updates (Decoding -> Effects -> Mastering) so you know exactly when your preview is ready to play. This lets you hear changes as you tweak the sliders, without waiting for a full render.

### 💾 Automatic Project Saving

Slowverb uses your browser's **IndexedDB** storage to automatically save your projects. This means:

- Your work is saved locally, even if you close the tab.
- You can return later and pick up where you left off via the **Library** screen.

### 📤 Multiple Export Formats

Export your finished audio in one of four formats:

| Format   | Quality                   | Best For                           |
|----------|---------------------------|------------------------------------|
| **MP3**  | Compressed (128-320 kbps) | Sharing, streaming, small files.   |
| **AAC**  | Compressed (128-256 kbps) | Modern codec, better quality/size. |
| **WAV**  | Uncompressed (Lossless)   | Professional use, no quality loss. |
| **FLAC** | Compressed (Lossless)     | Archiving, high-quality storage.   |

### 🎛️ Mastering & Quality

Slowverb features a professional-grade mastering engine powered by **PhaseLimiter**. This ensures your tracks have consistent loudness and punch without clipping.

#### The New PhaseLimiter Interface

Access the standalone **PhaseLimiter AI** interface from the home screen to master multiple files at once. It features:

- **Batch Processing**: Drop up to 50 files for automated mastering.
- **Target LUFS**: Choose your loudness level (e.g., -14 for Streaming, -11 for Club).
- **Bass Preservation**: Maintain low-end punch even during aggressive limiting.
- **Zip Export**: Bundle all mastered tracks into a single ZIP archive.

#### Mastering Quality Levels

| Level      | Engine              | Description                                      | Processing Time |
|------------|---------------------|--------------------------------------------------|-------------|
| **Simple** | Soft Clipper        | Basic peak limiting. Prevents red-lining.       | Instant     |
| **Lite (L3)**| PhaseLimiter (Lite) | Single-band lookahead limiting with spectral balancing. | Fast        |
| **Pro (L5)** | PhaseLimiter (Pro)  | **Multi-band AI optimization**. Uses heuristic search to find perfect DSP parameters for your specific audio. | Slow        |

> **Note**: The "Pro" mode (Level 5) runs a complex optimization loop directly in your browser. It provides the highest quality and most transparent loudness but may take 20-60 seconds per track.

To enable mastering in the editor:

1. Open the editor screen.
2. Toggle the "Mastering" switch in the unified bubble.
3. Adjust the **Quality** slider to your preference.
4. Regenerate your preview to hear the difference.

For batch mastering, use the **PHASELIMITER** button on the home screen.

---

## How It Works

Here's a simplified breakdown of what happens when you use Slowverb:

```
┌──────────────┐     ┌───────────────────┐     ┌────────────────┐
│  Your Audio  │ ──► │  FFmpeg.wasm      │ ──► │  Processed     │
│  File (.mp3) │     │  (in Web Worker)  │     │  Output (.mp3) │
└──────────────┘     └───────────────────┘     └────────────────┘
       ▲                       │
       │                       ▼
   File Picker           DSP Filter Chain
   (Browser API)         (tempo, pitch, reverb, etc.)
```

1. **Import**: You select an audio file using the browser's file picker.
2. **Load**: The file is loaded into memory (not uploaded anywhere).
3. **Process**: FFmpeg.wasm applies audio filters (tempo, pitch, reverb, etc.) in a background Web Worker.
4. **Master (Optional)**: If enabled, the audio is passed to the PhaseLimiter engine (Lite or Pro) for loudness maximization.
5. **Preview**: A short preview is generated so you can hear the result.
6. **Export**: The full audio is rendered and downloaded to your computer.

---

## Getting Started (Users)

1. **Open the app**: Go to **[https://slowverb.vercel.app/](https://slowverb.vercel.app/)**.
2. **Import a file**: Click "Drop audio file here" or "click to browse" to select an MP3, WAV, FLAC, M4A, AAC, or OGG file.
3. **Choose a preset**: Click the preset button (e.g., "Slowed + Reverb") to apply a pre-configured effect.
4. **Fine-tune**: Adjust the sliders (Tempo, Pitch, Reverb, Echo, Warmth) to taste.
5. **Preview**: Click the **Preview** button to hear a sample of the processed audio.
6. **Export**: Navigate to the **Export** screen, choose your format (MP3, AAC, WAV, FLAC), and click **Start Export**.
7. **Download**: Once processing is complete, your new audio file will download automatically.

---

## Effect Presets

Slowverb includes **16 curated presets** to get you started quickly:

| Preset             | Tempo   | Pitch    | Reverb | Echo  | Warmth | Description                       |
|--------------------|---------|----------|--------|-------|--------|-----------------------------------|
| **Slowed + Reverb**| 0.95x   | -2 semi  | 49%    | 20%   | 40%    | Classic dreamy vaporwave.         |
| **Lite Slowed + Reverb** | 0.86x | -2.61 semi | 1.48% wet | Off | Off | Gentle slow-down with high-density Freeverb spatial reverb |
| **Retro Nightcore** | 1.10x | +2.65 semi | Off | Off | Off | Analog coupled nightcore with bass boost |
| **Slow Bass** | 0.77x | -6.17 semi | Off | Off | Off | Deep bass boost with dynamic normalization |
| **Slowed + Reverb 2**| 0.74x | -4.5 semi| 28%    | 15%   | 50%    | Precise -25.926% slowdown.        |
| **Slowed + Reverb 3**| 0.81x | -3.2 semi| 35%    | 20%   | 50%    | -19% speed with balanced reverb.  |
| **Slow Chill**     | 0.94x   | -3.5 semi| 59%    | 38%   | 83%    | Smooth slowed sound with warm reverb. |
| **Vaporwave Chill**| 0.78x   | -3 semi  | 56%    | 40%   | 70%    | Warm, nostalgic, lo-fi.           |
| **Nightcore**      | 1.25x   | +4 semi  | 21%    | 10%   | 20%    | Fast, high-pitched, energetic.    |
| **Echo Slow**      | 0.65x   | -4 semi  | 42%    | 80%   | 50%    | Ultra slow with cascading echoes. |
| **Lo-Fi**          | 0.92x   | -1 semi  | 35%    | 30%   | 80%    | Relaxed, warm, dusty sound.       |
| **Ambient Space**  | 0.70x   | -2.5 semi| 63%    | 60%   | 30%    | Ethereal, floating atmosphere.    |
| **Deep Bass**      | 0.80x   | -5 semi  | 28%    | 20%   | 90%    | Heavy low-end focus.              |
| **Crystal Clear**  | 1.00x   | +2 semi  | 14%    | 10%   | 10%    | Crisp, bright, clean.             |
| **Underwater**     | 0.72x   | -3.5 semi| 59%    | 50%   | 60%    | Muffled, submerged atmosphere.    |
| **Synthwave**      | 1.05x   | +1 semi  | 42%    | 40%   | 40%    | Retro 80s vibes.                  |
| **Slow Motion**    | 0.55x   | -6 semi  | 49%    | 60%   | 50%    | Extreme slow-down effect.         |
| **Manual**         | 1.00x   | 0 semi   | 0%     | 0%    | 50%    | Start from scratch.               |

### 💾 Custom Presets

You can now create your own custom presets!

1. Select **Manual** mode or tweak any existing preset.
2. Click the **Save** button that appears in the preset list header.
3. Give your preset a name and description.
4. It will appear at the bottom of the presets list, saved to your browser's local storage.

---

## Analog & Freeverb Sound Profiles

Slowverb includes presets and DSP profiles inspired by classic analog tape and vintage digital sound signatures:

- **Freeverb Reverb Engine**: A pure JavaScript implementation of SoX’s Freeverb algorithm (8 parallel comb filters + 4 serial allpass filters), matching classical acoustic reverb character.
- **Coupled Speed Mode**: Presets use coupled tempo+pitch (like vintage tape slowdowns), producing the characteristic tape-resample effect.
- **New Effects**: Phaser modulation (for Vaporwave Chill) and bass shelf EQ (for Slow Bass, Retro Nightcore).
- **Dynamic Normalization**: Dynamic level control (`dynaudnorm`) for the Slow Bass preset.

These presets use the `reverb: freeverb` quality setting, which generates impulse responses using the SoX-matched algorithm directly in the browser.

## Visualizers

While your audio plays, Slowverb displays an animated visualizer that reacts to the music. Choose from **12 retro-inspired visual styles**:

| Visualizer | Description |
|------------|-------------|
| **Pipes** | Windows 3D Pipes homage with neon gradients. |
| **Starfield Warp** | A classic starfield "flight through space" effect driven by audio volume. |
| **Maze Neon** | Neon maze runner with turn frequency driven by mid frequencies. |
| **Maze Repeat** | CPU-based neon maze with specialized repeating patterns. |
| **Fractal Dream** | Mandelbrot/Julia fractal zooms with shifting color palettes. |
| **Fractal Dreams 3D** | Enhanced fractal journey with spatial warping and chromatic effects. |
| **WMP Retro** | Nostalgic Windows Media Player-style bars and waves. |
| **Mystify** | Classic polygon morphing screensaver. |
| **DVD Bounce** | Bouncing logo homage that changes color on impact. |
| **Rainy Window** | 90s PC box gazing at a stormy day with lightning. |
| **Rainy Window 3D** | GPU-accelerated 3D scene with PC, CRT, rain, and lightning. |
| **Time Gate** | 3D time portal tunnel with temporal distortion effects. |

Visualizers are rendered using **GPU shaders (GLSL)** via Flutter's `FragmentShader` API.

---

## Export Formats

| Format | Description                                                                                   |
|--------|-----------------------------------------------------------------------------------------------|
| **MP3**| The most widely compatible format. Small file sizes (lossy compression). Configurable bitrate (128-320 kbps). |
| **AAC**| Modern, efficient codec. Better quality than MP3 at the same bitrate. Configurable bitrate (128-256 kbps). |
| **WAV**| Uncompressed, lossless audio. Large file sizes. Best for professional editing.               |
| **FLAC**| Lossless compression. Smaller than WAV, but with no quality loss. Good for archiving.        |

> **Note**: FLAC export is only enabled when the source audio is a lossless format (WAV, FLAC). If you import an MP3, exporting to FLAC won't improve quality.

---

## Project Library

Slowverb automatically saves your work to **IndexedDB**, your browser's built-in database. This includes:

- The original filename.
- Your selected preset.
- All effect parameters.
- The last export format and date.

To access your saved projects:

1. Go to the **Library** screen from the import page.
2. Click **Open** on any project to resume editing.
3. Click **Delete** to remove a project from storage.

> **Tip**: If you clear your browser's site data, your saved projects will be lost.

---

## Technical Architecture

Slowverb is built with a modern, modular architecture:

### Frontend (UI Layer)

- **Flutter Web**: Cross-platform UI framework compiled to HTML/CSS/JavaScript.
- **State Management**: `flutter_riverpod` for reactive state management.
- **Routing**: `go_router` for URL-based navigation.

### Audio Engine

- **FFmpeg.wasm**: A WebAssembly port of FFmpeg (`@ffmpeg/ffmpeg`). Handles all DSP (Digital Signal Processing) tasks.
- **PhaseLimiter WASM**: Custom C++ port of the PhaseLimiter engine for professional mastering.
- **Web Workers**:
  - `audio_worker.js`: Handles FFmpeg processing.
  - `phase_limiter_pro_worker.js`: Handles "Pro" mode mastering (intensive).
- **Filter Chain**: The Dart code constructs an FFmpeg filter chain string based on your settings (e.g., `atempo=0.85,asetrate=44100*0.9,aecho=...`).

### Audio Playback

- **Web Audio API** (via `just_audio`): For real-time audio playback.
- **Blob URLs**: Processed audio is converted to a Blob URL for seamless playback.

### Persistence

- **IndexedDB** (via `idb_shim`): Stores project metadata and file handles (where supported).
- **File System Access API** (Chrome/Edge): Allows re-opening files without re-selecting them.

---

## Developer Setup

### Prerequisites

- **Flutter SDK**: 3.41.2 or higher.
- **Node.js**: (Optional) For testing the JavaScript worker.
- **Google Chrome**: For development and testing.

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/soficis/Slowverb.git
cd Slowverb

# 2. Navigate to the web project
cd web

# 3. Install Flutter dependencies
flutter pub get

# 4. Run the development server
flutter run -d chrome
```

### WASM Build Setup (Optional)

To modify or rebuild the PhaseLimiter C++ engine:

1. **Install Emscripten**: Follow the [Emscripten SDK instructions](https://emscripten.org/docs/getting_started/downloads.html).
2. **Build WASM Modules**:

```bash
cd wasm/phaselimiter

# Windows
./build.ps1

# Linux/macOS
./build.sh
```

This will compile `adapter_pro.cpp` and copy the resulting `phaselimiter_pro.js` and `phaselimiter_pro.wasm` to `web/web/js/`.

### Production Build & Local Server

```bash
cd web
npm run build          # Builds TypeScript engine & syncs bridge assets
flutter build web --release  # Compiles Flutter web bundle
npm run serve          # Serves app at http://localhost:8080 with COOP/COEP headers
```

The output will be in `build/web/` (when run from the `web/` directory). You can deploy this folder to any static hosting service (Vercel, Netlify, GitHub Pages, etc.).

---

## Project Structure

```
Slowverb/
├── wasm/                         # C++ Source for WASM Modules
│   └── phaselimiter/             # PhaseLimiter (Pro) Source
│       ├── stubs/                # IPP/TBB/FFTW Stubs
│       ├── adapter_pro.cpp       # JS <-> C++ Bridge
│       └── CMakeLists.txt        # Build Configuration
├── web/                          # Flutter Web Application
│   ├── lib/
│   │   ├── app/                  # App configuration, routing, colors
│   │   ├── domain/               # Data models (entities, repositories)
│   │   │   ├── entities/         # EffectPreset, Project, AudioMetadata, etc.
│   │   │   └── repositories/     # AudioEngine interface
│   │   ├── engine/               # Audio engine implementation
│   │   │   ├── wasm_audio_engine.dart  # Main engine class
│   │   │   └── filter_chain_builder.dart # FFmpeg filter string builder
│   │   ├── features/             # UI Screens
│   │   │   ├── import/           # File import screen
│   │   │   ├── editor/           # Main audio editor
│   │   │   ├── export/           # Export screen
│   │   │   ├── library/          # Project library
│   │   │   ├── settings/         # Settings screen
│   │   │   ├── about/            # About screen
│   │   │   └── visualizer/       # GPU visualizers
│   │   ├── providers/            # Riverpod state providers
│   │   └── utils/                # Utility functions
│   ├── web/
│   │   ├── index.html            # Entry HTML
│   │   ├── manifest.json         # PWA manifest
│   │   └── js/
│   │       ├── audio_worker.js   # Web Worker (FFmpeg processing)
│   │       ├── phase_limiter_pro_worker.js # Web Worker (Pro Mastering)
│   │       └── slowverb_bridge.js # Dart ↔ JS interop
│   ├── shaders/                  # GLSL fragment shaders for visualizers
│   │   ├── pipes_3d.frag
│   │   ├── starfield.frag
│   │   ├── maze_3d.frag
│   │   └── wmp_retro.frag
│   └── pubspec.yaml              # Flutter dependencies
├── docs/                         # Documentation
└── README.md                     # This file
```

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPLv3).

### FFmpeg Attribution

Slowverb uses [FFmpeg](https://ffmpeg.org) compiled to WebAssembly via `@ffmpeg/ffmpeg`. FFmpeg is licensed under [LGPL 2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). No modifications were made to the FFmpeg source code.

### PhaseLimiter Integration

Slowverb features a custom WebAssembly port of the **PhaseLimiter** engine (originally by [Shin Fukuse](https://github.com/ai-mastering/phaselimiter)). This powers the **Lite** and **Pro** mastering qualities, providing transparent peak limiting and loudness maximization directly in the browser.

#### How It Works (Technical Breakdown)

PhaseLimiter uses a multi-stage process to achieve professional loudness:

1. **Multi-Band Analysis (FFT)**: The audio is split into multiple frequency bands using Fast Fourier Transforms.
2. **Loudness Modeling**: The engine calculates multi-band loudness vectors, accounting for human hearing sensitivity (K-weighting/EBU R128 models).
3. **Heuristic Optimization (AI)**: In **Pro (Level 5)** mode, the engine runs a global optimization algorithm (Differential Evolution or PSO). It tries thousands of parameter combinations for threshold, gain, and ratio across all bands to minimize the distance between your audio and a professional "gold standard" reference.
4. **DSP Application**: Once optimized, multi-band compressors and a lookahead limiter are applied to the audio signal.
5. **Soft Clipping**: A final soft clipper ensures that even with aggressive gain, the audio never exceeds 0 dBFS.

The integration replaces heavy desktop dependencies (Intel IPP/TBB) with standard C++ and custom FFT implementations to ensure high performance in a single-threaded WebAssembly environment.

```
PhaseLimiter - MIT License
Copyright (c) 2023 Shin Fukuse
https://github.com/ai-mastering/phaselimiter
```

---

<p align="center">
  <strong><a href="https://slowverb.vercel.app/">🚀 Try Slowverb Live → https://slowverb.vercel.app/</a></strong>
</p>
