// End-to-end tests of the real orchestrator binary through the WebView2 DevTools protocol (Windows).
// Started by scripts/test-secondbrain-orchestrator-e2e.ps1, which builds the synthetic SecondBrain and passes it in SB_E2E_FIXTURE.
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: /.*\.spec\.ts/,
  timeout: 240_000,
  expect: { timeout: 30_000 },
  workers: 1,
  fullyParallel: false,
  retries: 0,
  reporter: [["list"]],
  outputDir: process.env.SB_E2E_OUTPUT ?? "test-results",
});
