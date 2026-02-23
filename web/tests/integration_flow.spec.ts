import { expect, test } from "@playwright/test";
import { readFixture, waitForBridge } from "./helpers";

test("import -> preview -> export flow", async ({ page }) => {
  const source = readFixture("test-short.wav");
  await waitForBridge(page);

  const outputSizes = await page.evaluate(async ({ source }) => {
    const bridge = (window as any).SlowverbBridge;
    const sourcePayload = {
      fileId: source.fileId,
      filename: source.filename,
      data: new Uint8Array(source.bytes).buffer,
    };

    const probe = await bridge.loadAndProbe({ source: sourcePayload });
    const preview = await bridge.renderPreview({
      source: sourcePayload,
      dspSpec: {
        specVersion: "1.0.0",
        tempo: 0.92,
        reverb: { decay: 0.3, preDelayMs: 40, mix: 0.25 },
      },
      format: "mp3",
      jobId: "integration-preview",
    });
    const full = await bridge.renderFull({
      source: sourcePayload,
      dspSpec: { specVersion: "1.0.0", tempo: 0.92 },
      format: "wav",
      jobId: "integration-full",
    });

    return {
      durationMs: probe.payload.durationMs,
      previewJobId: preview.payload.jobId,
      fullSize: full.payload.outputBuffer.byteLength,
    };
  }, { source });

  expect(outputSizes.durationMs).toBeGreaterThan(0);
  expect(outputSizes.previewJobId).toBe("integration-preview");
  expect(outputSizes.fullSize).toBeGreaterThan(1000);
});
