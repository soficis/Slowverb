# Known limits and open calls (web)

Revisit after real-song testing. Values here are guesses or taste calls, not measurements.

## Hard limits (guesses; tune with real files)

| Limit | Value | Where | Effect when hit |
|---|---|---|---|
| PhaseLimiter mastering timeout | 30 min | `web/packages/core-worker/src/worker_effects.ts` (`PHASE_LIMITER_TIMEOUT_MS`) | Render fails with "PhaseLimiter timed out"; worker is terminated |
| Batch in-flight audio | 300 MB aggregate | `web/lib/engine/wasm_audio_engine_impl.dart` | Batch waits/limits files to stay under the cap |
| Level 3 mastering memory | 1 GB WASM heap (`getHeapMax` in `web/web/js/phaselimiter.js`) | Long tracks fail with "Track too long for Level 3 mastering"; a 78-min file failed (needs 1.65 GB for the input buffers alone). Level 5 (Pro) allows 4 GB. Raising Level 3 needs a rebuild with a larger `MAXIMUM_MEMORY` |
| Fixed render sample rate | 44.1 kHz | `filter-compiler.ts` (`DEFAULT_SAMPLE_RATE`) | Higher-rate sources are resampled |

Browser memory is the real ceiling: a long lossless file is decoded to 32-bit float in memory several times
over (decode, effects, mastering). Users should be warned before rendering very long or very large files,
especially with PhaseLimiter Pro on mobile. The editor shows a one-time warning when a track of 10 minutes
or more loads (`_longTrackWarning` in `web/lib/features/editor/editor_screen.dart`); the threshold is a guess. It also fires for files of 100 MB or more, because the probe reported no duration for a very long file in testing.

## Sound taste calls (decide by ear)

- Echo is much softer than before the fixes (`aecho=1:1:<delay>:<feedback×0.5>`).
- Reverb blend is linear: at mix 0.3 the output is ~2.5 dB quieter than dry. Equal-power blending was not adopted.
- Simple mastering is ~1.7 dB quieter than the old (clipping) chain.
- IR makeup gains in `web/packages/shared/src/ir-registry.ts` are calibrated on pink noise (K-weighted);
  gramophone and plate split the difference with a music-like signal.

## Untested

- Desktop click-through with real songs passed (presets, devices, reverbs, sliders, MP3/WAV/FLAC export, Level 3 and 5 mastering, batch ZIP).
- Phone not tested.
- Not yet re-tested: the size-based warning and the new "too long" mastering message (needs the long file).
- Flutter browser tests (`flutter test --platform chrome`) do not load on the main dev machine (environmental).
