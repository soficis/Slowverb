## Architecture Comparison

This WASM port is a **simplified re-implementation** optimized for the browser. It captures the designated "automatic mastering" workflow (Target Lufs + Spectral Balance) but replaces heavy desktop dependencies with lightweight standard C++17 algorithms.

| Feature | Original PhaseLimiter (Desktop) | WASM Port (Web/Slowverb) |
|:---|:---|:---|
| **Threading** | Multi-threaded (Intel TBB) | Single-threaded (Main thread safe) |
| **Dependencies** | Intel IPP, TBB, Boost | **None** (Standard C++17 only) |
| **Loudness Metering** | EBU R128 (K-Weighted, Gated) | RMS (Flat, Ungated) |
| **Processing** | Multi-band Optimization + FFT | 2-Band Spectral Balancer (200Hz Split) |
| **Limiter** | Sophisticated Lookahead/TruePeak | Low-latency Hard Limiter |
| **Binary Size** | Large (Dynamic Libs) | Tiny (~20KB WASM) |

## Implementation Breakdown

### 1. The Original Approach (Reference)

The original PhaseLimiter uses `bakuage` libraries for sophisticated analysis:

```cpp
// Original (Conceptual)
#include <bakuage/loudness_ebu_r128.h>
#include <bakuage/serialized_runner.h>

void RunMany(Files files) {
  // 1. Analyze entire file with EBU R128 (Simulated)
  EbuR128 meter;
  meter.process(samples);
  double loudness = meter.integrated_loudness();
  
  // 2. Multi-band optimization using FFT/DCT
  // 3. True Peak Limiting
}
```

### 2. The WASM Port (`adapter.cpp`)

The WASM port mimics this 2-pass workflow using a zero-dependency approach suitable for immediate browser execution:

```cpp
// adapter.cpp
int run_phase_limiter(...) {
  // Pass 1: Analysis (RMS instead of R128)
  float inputDb = std::max(calculateRmsDb(left), calculateRmsDb(right));
  float gainDb = targetLufs - inputDb; 
  float gain = pow(10, gainDb / 20.0);

  // Pass 2: Apply Spectral Balancing & Limiting
  applySpectralGain(left, sampleRate, gain, bassPreservation);
  applyHardLimiter(left, right, 0.95f);
}
```

#### Spectral Balancing

Instead of complex multi-band FFT processing, we use a computationally cheap 1-pole Lowpass filter to split frequencies at 200Hz:

- **Low Frequencies (<200Hz)**: Gain is scaled by `bassPreservation` (0.0 = full boost, 1.0 = no boost).
- **High Frequencies (>200Hz)**: Full gain is applied to bring volume up to target.

#### Hard Limiter

A standard memoryless hard limiter with a ceiling of **-0.5 dB** (0.95 linear) prevents digital clipping after gain application.

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

- **Large files stall**: Ensure `SharedArrayBuffer` is available or that files aren't exceeding browser memory limits (~2GB is often the hard cap for WASM heaps in some contexts).
- **Clipping**: If input is extremely dynamic, the simple hard limiter might sound harsh. This port prioritizes speed and code size over transparent limiting.
