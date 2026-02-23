import { expect, test } from "@playwright/test";
import { readFixture, waitForBridge } from "./helpers";

const formats: Array<"mp3" | "wav" | "flac"> = ["mp3", "wav", "flac"];

for (const format of formats) {
  test(`renderFull exports ${format}`, async ({ page }) => {
    const source = readFixture("test-short.mp3");
    await waitForBridge(page);

    const byteLength = await page.evaluate(async ({ source, format }) => {
      const bridge = (window as any).SlowverbBridge;
      const result = await bridge.renderFull({
        source: {
          fileId: source.fileId,
          filename: source.filename,
          data: new Uint8Array(source.bytes).buffer,
        },
        dspSpec: { specVersion: "1.0.0", tempo: 1.0 },
        format,
        jobId: `render-${format}`,
      });
      return result.payload.outputBuffer.byteLength;
    }, { source, format });

    expect(byteLength).toBeGreaterThan(1000);
  });
}
