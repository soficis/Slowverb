import { expect, test } from "@playwright/test";
import { readFixture, waitForBridge } from "./helpers";

test("batch export flow renders multiple files", async ({ page }) => {
  const first = readFixture("test-short.mp3");
  const second = readFixture("test-short.flac");
  await waitForBridge(page);

  const outputs = await page.evaluate(async ({ first, second }) => {
    const bridge = (window as any).SlowverbBridge;

    const renderOne = async (input: any, jobId: string) => {
      const result = await bridge.renderFull({
        source: {
          fileId: input.fileId,
          filename: input.filename,
          data: new Uint8Array(input.bytes).buffer,
        },
        dspSpec: { specVersion: "1.0.0", tempo: 1.0 },
        format: "mp3",
        jobId,
      });
      return result.payload.outputBuffer.byteLength;
    };

    const [a, b] = await Promise.all([
      renderOne(first, "batch-a"),
      renderOne(second, "batch-b"),
    ]);

    return [a, b];
  }, { first, second });

  expect(outputs[0]).toBeGreaterThan(1000);
  expect(outputs[1]).toBeGreaterThan(1000);
});
