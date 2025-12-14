import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 60_000,
  fullyParallel: false,
  retries: 1,

  use: {
    baseURL: "http://localhost:8080",
    trace: "on-first-retry",
  },

  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
  ],

  webServer: {
    command: "flutter run -d chrome --web-port=8080",
    url: "http://localhost:8080",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
