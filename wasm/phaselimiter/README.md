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

The standard WASM port (`adapter.cpp`) mimics the 2-pass workflow using a zero-dependency approach:

```cpp
// adapter.cpp
int run_phase_limiter(...) {
  // Pass 1: Analysis (RMS instead of R128)
  float gainDb = targetLufs - calculateRmsDb(input); 

  // Pass 2: Apply Spectral Balancing & Limiting
  applySpectralGain(left, sampleRate, gain, bassPreservation);
  applyHardLimiter(left, right, 0.95f);
}
```

#### Spectral Balancing

- **Low Frequencies (<200Hz)**: Gain is scaled by `bassPreservation`.
- **High Frequencies (>200Hz)**: Full gain is applied.

### 3. Pro Mode Optimization (`adapter_pro.cpp` / Level 5)

The Pro mode (`AutoMastering5`) uses a sophisticated multi-band heuristic optimization engine to find the ideal DSP parameters for a given track.

#### The Optimization Loop

PhaseLimiter Level 5 treats mastering as a mathematical optimization problem:

1. **Objective Function**: $Eval = Distance(Audio, Reference) + \alpha \cdot MSE + \beta \cdot Penalty$.
    - **Distance**: How close the audio's spectral balance and dynamics are to a professional reference model (`SoundQuality2Calculator`).
    - **MSE**: Ensures the processed audio doesn't deviate *too* drastically from the original's intent.
    - **Penalty**: Disincentivizes extreme compressor settings that might cause artifacts.
2. **Parameters**: The engine optimizes 8 parameters per frequency band (Threshold, Wet Gain, Dry Gain, Ratio for both Mid and Side channels).
3. **Search Algorithms**: Supports several heuristic solvers:
    - **Differential Evolution (DE)**: Population-based global search.
    - **Particle Swarm Optimization (PSO)**: Swarm-based search.
    - **Nelder-Mead (NM)**: Simplex-based local optimization.
4. **Early Termination**: Optimized for web performance. If no improvement is found within **500 evaluations** (patience), the search stops early. The global maximum is typically capped at **4000 evaluations**.

#### Multi-Band Implementation

- **Filter Bank**: Uses FIR bandpass filters (via `CalculateBandPassFir`) to split the audio into highly specific frequency regions.
- **Parallel Processing**: Optimization is followed by a parallelized application of the best parameters to each band using `tbb::parallel_for` (or standard loops in single-threaded WASM).
- **Fallback Mechanism**: If Level 5 optimization fails or throws an exception, the system automatically falls back to Level 3 to ensure the user always gets a mastered file.

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
