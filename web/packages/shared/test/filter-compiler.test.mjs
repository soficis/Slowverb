import test from "node:test";
import assert from "node:assert/strict";

import { compileFilterChain, PRESETS } from "../dist/index.js";

test("returns normalization chain when no parameters are provided", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0" });
  assert.equal(chain, "volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1");
});

test("clamps tempo and pitch to DSP limits", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    tempo: 0.1, // clamps to 0.5
    pitch: 24, // clamps to +12
  });

  assert.equal(
    chain,
    "atempo=0.5000,asetrate=44100*2.0000,aresample=44100:filter_size=64:phase_shift=10,volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1"
  );
});

test("eqWarmth and low-pass priority are respected", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    eqWarmth: 2, // clamps to 1.0 -> 6dB gain
    lowPassCutoffHz: -10, // clamps to 200 Hz and overrides hfDamping
    hfDamping: 1,
  });

  assert.equal(
    chain,
    "equalizer=f=300:t=h:width=200:g=6.0,lowpass=f=200,volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1"
  );
});

test("reverb and echo clamp values to safe ranges", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    reverb: {
      decay: 2, // clamps to 0.99
      preDelayMs: 1000, // clamps to 500
      roomScale: 2, // clamps to 1.0
      mix: 2, // clamps to 1.0
    },
    echo: {
      delayMs: 5000, // clamps to 1000
      feedback: 2, // clamps to 0.9
    },
  });

  assert.equal(
    chain,
    "aecho=0.8:1.00:500|850|1200|1300|1750:0.79|0.59|0.40|0.25|0.10,aecho=0.8:0.2:1000:0.6,volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1"
  );
});

test("composite chain preserves filter order", () => {
  const chain = compileFilterChain({
    ...PRESETS.SLOWED_REVERB,
    specVersion: "1.0.0",
    eqWarmth: 0.5,
    hfDamping: 0.25,
    stereoWidth: 0.8,
  });

  const markers = [
    "atempo=",
    "asetrate=",
    "equalizer=",
    "aecho=0.8:0.30:",
    "aecho=0.8:0.2:",
    "lowpass=f=",
    "stereotools=",
    "volume=6dB,",
    "alimiter=limit=0.95:level_in=1:level_out=1",
  ];

  const positions = markers.map((marker) => {
    const index = chain.indexOf(marker);
    assert.ok(index >= 0, `Expected marker ${marker} in chain`);
    return index;
  });

  for (let i = 1; i < positions.length; i += 1) {
    assert.ok(positions[i] > positions[i - 1], `Filter order violated for ${markers[i]}`);
  }
});

test("mastering disabled applies normalization chain", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    mastering: { enabled: false, algorithm: "simple" },
  });

  assert.equal(chain, "volume=6dB,alimiter=limit=0.95:level_in=1:level_out=1");
  assert.ok(chain.includes("alimiter="));
});

test("mastering enabled appends limiter at end", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    mastering: { enabled: true, algorithm: "simple" },
  });

  assert.ok(chain.endsWith("alimiter=limit=0.95"));
});

test("mastering enabled is last stage after stereo width", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    stereoWidth: 1.5,
    mastering: { enabled: true, algorithm: "simple" },
  });

  assert.ok(chain.includes("extrastereo="));
  assert.ok(chain.endsWith("alimiter=limit=0.95"));
  assert.ok(chain.indexOf("extrastereo=") < chain.indexOf("highpass=f=20"));
});

test("PhaseLimiter mastering does not append FFmpeg mastering filters", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    mastering: { enabled: true, algorithm: "phaselimiter" },
  });

  assert.equal(chain, "anull");
  assert.ok(!chain.includes("alimiter="));
});
