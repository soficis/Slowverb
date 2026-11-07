<h1 align="center">Slowverb</h1>

<p align="center"><strong>Your favourite song, slowed down and drowned in reverb, in about ten seconds.</strong></p>

<p align="center">
  <a href="https://slowverb.vercel.app/"><strong>▶ Open Slowverb</strong></a>
</p>

---

Drop in a song. Pick a preset. Hit play.

Slowverb runs in your browser. Your music never leaves your computer. There is nothing to install and no account to make.

## What you can do

- **Slow it down.** Tempo, pitch, reverb, echo, warmth, phaser and bass, all on faders.
- **Start from a preset.** 18 built in, from *Slowed + Reverb* to *Nightcore* to *Underwater*. Save your own.
- **Change the room.** Play the track through car speakers, a gramophone or a cassette deck. Put it in a plate reverb or a hotel bathroom.
- **Make it loud.** Built-in mastering evens out the volume and adds punch.
- **Watch it.** 13 retro visualizers run behind the controls. Pick one, or hit **Shuffle**.
- **Export it.** MP3, AAC, WAV or FLAC. Do a whole folder at once with batch export.
- **Come back later.** Your projects save themselves in the Library.

## How to use it

1. Open **[slowverb.vercel.app](https://slowverb.vercel.app/)**.
2. Drop an audio file on the start screen (MP3, WAV, FLAC, M4A, AAC or OGG).
3. Pick a preset from the **Sound** window. Nudge the faders until it feels right.
4. Press play. Press **Space** to pause.
5. Click **Export**, choose a format, and download.

**Tip:** Click any fader's value to type an exact number.

## Mastering

Turn on **Master** in the Sound window. Then pick a level:

| Level | Speed | What it does |
|---|---|---|
| **Level 3** | Fast | Clean, loud and safe. Good for most songs. |
| **Level 5** | Slow | Tunes the mastering to your song. Takes longer. Sounds best. |

Want to master a stack of files without editing them? Use **Mastering** on the start screen.

## Good to know

- **Use Chrome on a computer.** Other browsers may work. Chrome is the one we test.
- **Long songs need lots of memory.** Tracks over 10 minutes show a warning. Very long tracks (an hour or more) can fail to master, especially on phones. Turn mastering off or use a desktop browser.
- **FLAC export needs a lossless source.** Turning an MP3 into FLAC can't add back lost quality, so Slowverb doesn't offer it.
- **Clearing your browser data deletes your Library.** Projects live in your browser, not in the cloud.

<details>
<summary><strong>All 18 presets</strong></summary>

| Preset | Tempo | Pitch | Vibe |
|---|---|---|---|
| Slowed + Reverb | 0.95× | −2 st | Classic dreamy slowed + reverb |
| Lite Slowed + Reverb | 0.86× | −2.61 st | Gentle slowdown, dense reverb |
| Slowed + Reverb 2 | 0.74× | −4.5 st | Deeper and slower |
| Slowed + Reverb 3 | 0.81× | −3.2 st | Balanced middle ground |
| Slow Chill | 0.94× | −3.5 st | Smooth and warm |
| Vaporwave Chill | 0.78× | −3 st | Nostalgic, with phaser shimmer |
| Echo Slow | 0.65× | −4 st | Ultra slow, cascading echoes |
| Lo-Fi | 0.92× | −1 st | Relaxed and dusty |
| Ambient Space | 0.70× | −2.5 st | Floating, ethereal |
| Underwater | 0.72× | −3.5 st | Muffled and submerged |
| Slow Motion | 0.55× | −6 st | Extreme slowdown |
| Slow Bass | 0.77× | −6.17 st | Deep bass boost |
| Deep Bass | 0.80× | −5 st | Heavy low end |
| Nightcore | 1.25× | +4 st | Fast and bright |
| Retro Nightcore | 1.10× | +2.65 st | Tape-style nightcore with bass |
| Synthwave | 1.05× | +1 st | Retro 80s |
| Crystal Clear | 1.00× | +2 st | Crisp and clean |
| Manual | 1.00× | 0 st | Start from scratch |

Save your own: tweak any preset, then press **Save** next to the preset menu.

</details>

<details>
<summary><strong>All 13 visualizers</strong></summary>

Pipes · Starfield Warp · Maze Neon · Maze Repeat · Fractal Dream · Fractal Dreams 3D · WMP Retro · Mystify · DVD Bounce · Rainy Window · Rainy Window 3D · Time Gate · Vortex

**Shuffle** rotates through the calmer ones every two minutes while music plays. Time Gate, Vortex and the novelty scenes stay out of the shuffle because they flash too hard behind the controls.

</details>

---

## For the nerds

Everything below is optional. Open what you need.

<details>
<summary><strong>How it works</strong></summary>

```
Your file ──► FFmpeg.wasm (Web Worker) ──► effects chain ──► PhaseLimiter (optional) ──► preview / export
```

1. **Load.** The file is read into memory. Nothing is uploaded.
2. **Process.** A Web Worker runs FFmpeg compiled to WebAssembly. It applies tempo, pitch, reverb, echo, EQ, phaser and bass.
3. **Stretch.** High-quality time-stretching uses SoundTouch, which avoids the metallic sound of naive slowdowns.
4. **Room.** Playback devices and the plate and bathroom reverbs are convolution impulse responses (IRs). The algorithmic reverb is a SoX-style Freeverb whose IR is generated in the browser.
5. **Master.** PhaseLimiter, compiled to WebAssembly, limits and balances loudness.
6. **Play or export.** The result plays from a Blob URL or downloads as a file.

</details>

<details>
<summary><strong>Tech stack</strong></summary>

- **UI:** Flutter Web, Riverpod, go_router. Custom "after-hours Mac + hi-fi deck" design system in `web/lib/app/retro/`.
- **Audio engine:** TypeScript packages (`web/packages/shared`, `core`, `core-worker`) wrapping FFmpeg.wasm 5.1.
- **Mastering:** PhaseLimiter ported to WebAssembly. Level 3 uses a 1 GB WASM heap. Level 5 (Pro) allows 4 GB.
- **Visualizers:** GLSL fragment shaders via Flutter's `FragmentShader`.
- **Storage:** IndexedDB via `idb_shim`, with a localStorage fallback. The File System Access API lets Chrome and Edge reopen files.
- **Offline:** A service worker serves app code network-first and big static assets (fonts, IRs, WASM) cache-first.
- **Headers:** FFmpeg and PhaseLimiter need `SharedArrayBuffer`, so the app is served with COOP/COEP headers (see `web/vercel.json`).

</details>

<details>
<summary><strong>Run it locally</strong></summary>

You need the Flutter SDK (3.41.2 or newer), Node.js and Chrome.

```bash
git clone https://github.com/soficis/Slowverb.git
cd Slowverb/web
npm install
npm run build              # builds the TypeScript engine and syncs bridge assets
flutter pub get
flutter build web --release
npm run serve              # http://localhost:8080 with COOP/COEP headers
```

`flutter run -d chrome` also works for quick UI work. Audio processing needs the COOP/COEP headers that `npm run serve` sets.

Checks:

```bash
npm run check:ts           # typecheck, lint, build the TS packages
npm run test:unit          # engine unit tests
flutter analyze --no-pub
```

</details>

<details>
<summary><strong>Rebuild the PhaseLimiter WASM</strong></summary>

Install the [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html), then:

```bash
cd wasm/phaselimiter
./build.sh        # Linux/macOS
./build.ps1       # Windows
```

This compiles `adapter_pro.cpp` and copies `phaselimiter_pro.js` and `phaselimiter_pro.wasm` into `web/web/js/`.

**How Level 5 works.** The track is split into frequency bands with FFTs. The engine models loudness per band (K-weighting, EBU R128). It then runs a global optimizer (differential evolution or PSO) over threshold, gain and ratio for each band, aiming at a reference loudness profile. Multiband compressors, a lookahead limiter and a soft clipper finish the job. The port replaces Intel IPP and TBB with plain C++ and its own FFT, so it runs in single-threaded WebAssembly.

</details>

<details>
<summary><strong>Project layout</strong></summary>

```
Slowverb/
├── KNOWN_LIMITS.md          # guessed limits and open sound decisions
├── wasm/phaselimiter/       # C++ source for the mastering engine
└── web/                     # the app
    ├── lib/
    │   ├── app/             # theme, design tokens, retro widgets, routing
    │   ├── domain/          # presets, projects, visualizer definitions
    │   ├── engine/          # Dart side of the audio engine
    │   ├── data/            # IndexedDB repositories
    │   ├── features/        # screens: import, editor, export, batch, mastering, library…
    │   └── providers/       # Riverpod state
    ├── packages/            # TypeScript engine: shared, core, core-worker
    ├── shaders/             # GLSL visualizers
    └── web/
        ├── irs/             # impulse responses (+ their licence)
        ├── js/              # bridge, workers, FFmpeg and PhaseLimiter WASM
        └── sw.js            # service worker
```

</details>

<details>
<summary><strong>Known limits</strong></summary>

See [KNOWN_LIMITS.md](KNOWN_LIMITS.md) for the guessed limits (mastering timeout, batch memory cap, render sample rate) and the sound decisions still open.

</details>

---

## Credits and licence

Slowverb is free software under the **GNU GPL v3**.

- **FFmpeg** via `@ffmpeg/ffmpeg`. [LGPL 2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). Unmodified.
- **PhaseLimiter** by Shin Fukuse ([ai-mastering/phaselimiter](https://github.com/ai-mastering/phaselimiter)). MIT. Ported to WebAssembly for Slowverb.
- **Impulse responses** from the IR Library by Conner ([itsmusician/IR-Library](https://github.com/itsmusician/IR-Library)). MIT, © 2022 Conner. Licence text ships at `web/web/irs/LICENSE-itsmusician-IR-Library.md`.
- **Fonts:** Rajdhani, DotGothic16, DSEG and Roboto, all under the SIL Open Font License.
- **JSZip** for ZIP export. MIT.

<p align="center"><a href="https://slowverb.vercel.app/"><strong>▶ Open Slowverb</strong></a></p>
