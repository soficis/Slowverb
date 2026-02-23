import fs from "node:fs";
import path from "node:path";
import type { Page } from "@playwright/test";

export type SerializedSource = {
  readonly fileId: string;
  readonly filename: string;
  readonly bytes: number[];
};

export function readFixture(fixture: string): SerializedSource {
  const filePath = path.join(__dirname, "fixtures", fixture);
  const bytes = fs.readFileSync(filePath);
  return {
    fileId: `${fixture}-${Date.now()}`,
    filename: fixture,
    bytes: Array.from(bytes),
  };
}

export async function waitForBridge(page: Page): Promise<void> {
  await page.goto("/");
  await page.waitForFunction(
    () => Boolean((window as unknown as { SlowverbBridge?: unknown }).SlowverbBridge)
  );
}
