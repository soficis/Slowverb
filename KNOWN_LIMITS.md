# Known limits and open calls (web)

Revisit after real-song testing. Values here are guesses or taste calls, not measurements.

## Hard limits (guesses; tune with real files)

| Limit | Value | Where | Effect when hit |
|---|---|---|---|
| PhaseLimiter mastering timeout | 30 min | `web/packages/core-worker/src/worker_effects.ts` (`PHASE_LIMITER_TIMEOUT_MS`) | Render fails with "PhaseLimiter timed out"; worker is terminated |
| Batch in-flight audio | 300 MB aggregate | `web/lib/engine/wasm_audio_engine_impl.dart` | Batch waits/limits files to stay under the cap |
| Fixed render sample rate | 44.1 kHz | `filter-compiler.ts` (`DEFAULT_SAMPLE_RATE`) | Higher-rate sources are resampled |

Browser memory is the real ceiling: a long lossless file is decoded to 32-bit float in memory several times
over (decode, effects, mastering). Users should be warned before rendering very long or very large files,
especially with PhaseLimiter Pro on mobile. **TODO (UI pass):** add that warning in the import/export flow.

## Sound taste calls (decide by ear)

- Echo is much softer than before the fixes (`aecho=1:1:<delay>:<feedback×0.5>`).
- Reverb blend is linear: at mix 0.3 the output is ~2.5 dB quieter than dry. Equal-power blending was not adopted.
- Simple mastering is ~1.7 dB quieter than the old (clipping) chain.
- IR makeup gains in `web/packages/shared/src/ir-registry.ts` are calibrated on pink noise (K-weighted);
  gramophone and plate split the difference with a music-like signal.

## Untested

- No end-to-end click-through with a real song yet.
- Flutter browser tests (`flutter test --platform chrome`) do not load on the main dev machine (environmental).
