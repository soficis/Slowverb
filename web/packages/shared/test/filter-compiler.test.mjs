import test from "node:test";
import assert from "node:assert/strict";

import { compileFilterChain, PRESETS } from "../dist/index.js";

test("returns normalization chain when no parameters are provided", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0" });
  assert.equal(chain, "volume=3dB,alimiter=limit=0.95:level=disabled");
});

test("clamps tempo and pitch to DSP limits", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    tempo: 0.1, // clamps to 0.5
    pitch: 24, // clamps to +12
  });

  assert.equal(
    chain,
    "aresample=44100,asetrate=44100*2.0000,aresample=44100:filter_size=64:phase_shift=10,atempo=0.5,atempo=0.5000,volume=3dB,alimiter=limit=0.95:level=disabled"
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
    "equalizer=f=300:t=h:width=200:g=6.0,lowpass=f=200,volume=3dB,alimiter=limit=0.95:level=disabled"
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
    "aecho=1:1:500|850|1200|1300|1750:0.79200|0.59400|0.39600|0.24750|0.09900,aecho=1:1:1000:0.4500,volume=3dB,alimiter=limit=0.95:level=disabled"
  );
});

test("composite chain preserves filter order", () => {
  const chain = compileFilterChain({
    ...PRESETS.SLOWED_REVERB,
    quality: { reverb: "ffmpeg" },
    specVersion: "1.0.0",
    eqWarmth: 0.5,
    hfDamping: 0.25,
    stereoWidth: 0.8,
  });

  const markers = [
    "asetrate=",
    "atempo=",
    "equalizer=",
    "aecho=1:1:",
    "aecho=1:1:200:",
    "lowpass=f=",
    "stereotools=",
    "volume=3dB,",
    "alimiter=limit=0.95:level=disabled",
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

  assert.equal(chain, "volume=3dB,alimiter=limit=0.95:level=disabled");
  assert.ok(chain.includes("alimiter="));
});

test("mastering enabled appends limiter at end", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    mastering: { enabled: true, algorithm: "simple" },
  });

  assert.ok(chain.endsWith("alimiter=limit=0.95:level=disabled"));
});

test("mastering enabled is last stage after stereo width", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    stereoWidth: 1.5,
    mastering: { enabled: true, algorithm: "simple" },
  });

  assert.ok(chain.includes("extrastereo="));
  assert.ok(chain.endsWith("alimiter=limit=0.95:level=disabled"));
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

test("zero echo is off", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0", echo: { delayMs: 0, feedback: 0 } });
  assert.ok(!chain.includes("aecho"));
  assert.ok(!chain.includes(":50:"));
});

test("phaser params are sanitised", () => {
  const evil = compileFilterChain({
    specVersion: "1.0.0",
    phaser: { delayMs: 3, decay: 0.4, speedHz: 0.5, type: "s,volume=60dB" },
  });
  assert.ok(evil.includes("type=s"));
  assert.ok(!evil.includes("volume=60dB"));
  const fast = compileFilterChain({
    specVersion: "1.0.0",
    phaser: { delayMs: 3, decay: 0.4, speedHz: 5, type: "s" },
  });
  assert.ok(fast.includes("speed=2:"));
});

test("non-finite bassGain is skipped", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0", bassGain: NaN });
  assert.ok(!chain.includes("bass="));
});

test("coupled mode sanitises tempo and resamples to 44.1k first", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0", coupledMode: true, tempo: NaN });
  assert.ok(chain.startsWith("aresample=44100,asetrate=44100*1.0000"));
});

test("coupled mode honours pitch with a residual atempo", () => {
  const c = (tempo, pitch) => compileFilterChain({ specVersion: "1.0.0", coupledMode: true, tempo, pitch });
  const slowBass = c(0.77, -6.17);
  assert.ok(slowBass.includes("asetrate=44100*0.7002,"));
  assert.ok(slowBass.includes(",atempo=1.0997,"));
  const retro = c(1.1, 2.65);
  assert.ok(retro.includes("asetrate=44100*1.1654,"));
  assert.ok(retro.includes(",atempo=0.9439,"));
  const lite = c(0.86, -2.61);
  assert.ok(lite.includes("asetrate=44100*0.8601,"));
  assert.ok(!lite.includes("atempo"));
});

test("ffmpeg reverb keeps dry at unity and scales only the wet taps", () => {
  const rv = { decay: 0.5, preDelayMs: 20, roomScale: 0.5 };
  const small = compileFilterChain({ specVersion: "1.0.0", reverb: { ...rv, mix: 0.008 } });
  assert.ok(small.startsWith("aecho=1:1:"));
  assert.ok(small.includes(":0.00320|0.00240|0.00160|0.00100|0.00040"));
  const off = compileFilterChain({ specVersion: "1.0.0", reverb: { ...rv, mix: 0 } });
  assert.ok(!off.includes("aecho"));
});

test("tone and freeverb skip the aecho reverb", () => {
  for (const reverb of ["tone", "freeverb"]) {
    const chain = compileFilterChain({
      specVersion: "1.0.0",
      quality: { reverb },
      reverb: { decay: 0.5, preDelayMs: 20, mix: 0.3 },
    });
    assert.ok(!chain.includes("aecho"));
  }
});

test("echo keeps dry at unity and derives the tap from feedback", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0", echo: { delayMs: 300, feedback: 0.4 } });
  assert.ok(chain.startsWith("aecho=1:1:300:0.2000,"));
});

test("phaser uses the APK in/out gains", () => {
  const chain = compileFilterChain({
    specVersion: "1.0.0",
    phaser: { delayMs: 4, decay: 0.23, speedHz: 1.3, type: "s" },
  });
  assert.ok(chain.startsWith("aphaser=in_gain=0.9:out_gain=0.85:delay=4:decay=0.23:speed=1.3:type=s,"));
});

test("non-coupled pitch change keeps the requested tempo", () => {
  const chain = compileFilterChain({ specVersion: "1.0.0", tempo: 0.86, pitch: -2.61 });
  // Pitch-only asetrate would also slow playback; the residual atempo must cancel it.
  assert.ok(chain.startsWith("aresample=44100,asetrate=44100*0.8601,"));
  assert.ok(!chain.includes("atempo"));
  const tempoOnly = compileFilterChain({ specVersion: "1.0.0", tempo: 0.86 });
  assert.ok(tempoOnly.startsWith("atempo=0.8600,"));
  assert.ok(!tempoOnly.includes("asetrate"));
});
