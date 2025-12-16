# PhaseLimiter WASM (Plan B2)

Single‑threaded WebAssembly build of the PhaseLimiter mastering engine with a small C++ adapter that exposes a stable entrypoint to JavaScript workers.

## Overview

- Two‑pass processing: EBU R128 analysis → multiband optimization → render
- Threading removed (TBB stubbed) for browser compatibility
- FFT and SIMD fall back to scalar code paths
- Memory growth enabled; uses Transferable buffers in JS to avoid copies

### Key sources

- `adapter.cpp` – exports `run_phase_limiter` and progress callback plumbing
- `CMakeLists.txt` – emcc flags, include paths, exported runtime methods
- `stubs/` – minimal shims for threading/FFT where needed

## Build (Emscripten)

Artifacts are copied into the web app:

- `web/web/js/phaselimiter.js`
- `web/web/js/phaselimiter.wasm`

### Windows (PowerShell)

```powershell
cd wasm/phaselimiter
./build.ps1
```

### macOS/Linux (bash)

```bash
cd wasm/phaselimiter
./build.sh
```

If you don’t have Emscripten in PATH, source your emsdk environment first (e.g., `emsdk_env.ps1` or `emsdk_env.sh`).

## Adapter API

```c++
// run_phase_limiter(leftPtr, rightPtr, sampleCount, sampleRate, targetLufs, bassPreservation, progressCbPtr)
// Returns 0 on success, non‑zero error codes on failure.
```

- `leftPtr`, `rightPtr`: WASM heap pointers to Float32 samples
- `sampleCount`: number of samples per channel
- `sampleRate`: 8k–192k accepted
- `targetLufs`: e.g., -14.0
- `bassPreservation`: 0.0–1.0
- `progressCbPtr`: function pointer receiving `percent` in [0,1]

## Troubleshooting

- Build fails finding TBB/IPPs: ensure scalar fallbacks are used; the stubs disable threading.
- Large files stall in browser: verify Transferables are used and memory growth is on; test with `web/web/phaselimiter_test.html`.
- WASM not found at runtime: rebuild and confirm artifacts exist in `web/web/js/`.

