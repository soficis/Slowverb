import { expect, test } from "@playwright/test";
import { readFixture, waitForBridge } from "./helpers";

test("probes audio metadata through SlowverbBridge", async ({ page }) => {
  const source = readFixture("test-short.mp3");
  await waitForBridge(page);

  const metadata = await page.evaluate(async ({ source }) => {
    const bridge = (window as any).SlowverbBridge;
    const payload = await bridge.loadAndProbe({
      source: {
        fileId: source.fileId,
        filename: source.filename,
        data: new Uint8Array(source.bytes).buffer,
      },
    });
    return payload.payload;
  }, { source });

  expect(metadata.durationMs ?? 0).toBeGreaterThan(2000);
  expect(metadata.durationMs ?? 0).toBeLessThan(5000);
  expect(metadata.sampleRate).toBe(44100);
});

test("renderPreview returns audio data", async ({ page }) => {
  const source = readFixture("test-short.mp3");
  await waitForBridge(page);

  const byteLength = await page.evaluate(async ({ source }) => {
    const bridge = (window as any).SlowverbBridge;
    const result = await bridge.renderPreview({
      source: {
        fileId: source.fileId,
        filename: source.filename,
        data: new Uint8Array(source.bytes).buffer,
      },
      dspSpec: { specVersion: "1.0.0", tempo: 0.85, pitch: -2 },
      format: "mp3",
      jobId: "preview-job",
    });
    return result.payload.buffer.byteLength;
  }, { source });

  expect(byteLength).toBeGreaterThan(1000);
});

test("cancel responds even when no job is active", async ({ page }) => {
  await waitForBridge(page);
  const result = await page.evaluate(async () => (window as any).SlowverbBridge.cancel("missing-job"));
  expect(result.type).toBe("cancel-ok");
});
