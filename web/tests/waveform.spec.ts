import { expect, test } from "@playwright/test";
import { readFixture, waitForBridge } from "./helpers";

test("waveform returns normalized samples", async ({ page }) => {
  const source = readFixture("test-short.wav");
  await waitForBridge(page);

  const summary = await page.evaluate(async ({ source }) => {
    const bridge = (window as any).SlowverbBridge;
    const result = await bridge.waveform({
      source: {
        fileId: source.fileId,
        filename: source.filename,
        data: new Uint8Array(source.bytes).buffer,
      },
      points: 128,
    });

    const samples = Array.from(result.payload.samples);
    const min = samples.reduce((acc, value) => Math.min(acc, value), Number.POSITIVE_INFINITY);
    const max = samples.reduce((acc, value) => Math.max(acc, value), Number.NEGATIVE_INFINITY);

    return { length: samples.length, min, max };
  }, { source });

  expect(summary.length).toBeGreaterThan(50);
  expect(summary.min).toBeGreaterThanOrEqual(0);
  expect(summary.max).toBeLessThanOrEqual(1);
});
