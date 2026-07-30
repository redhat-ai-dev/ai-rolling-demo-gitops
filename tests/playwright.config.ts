import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@playwright/test";

/** Load `scripts/private-env` so local `npx playwright test` / `--ui` picks up auth vars. */
function loadPrivateEnv(): void {
  const envPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../scripts/private-env",
  );
  if (!existsSync(envPath)) {
    return;
  }

  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const match = trimmed.match(/^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) {
      continue;
    }

    const [, key, raw] = match;
    if (process.env[key] !== undefined) {
      continue; // prefer already-exported / CI values
    }

    let value = raw.trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

loadPrivateEnv();

const isHeadless =
  (process.env.PLAYWRIGHT_HEADLESS ?? "true").toLowerCase() !== "false";

export default defineConfig({
  testDir: "./specs",
  testMatch: [
    "**/lightspeed.spec.ts",
    "**/mcp.spec.ts",
    "**/notebook.spec.ts",
  ],
  timeout: 7 * 60 * 1000,
  expect: {
    timeout: 30_000,
  },
  workers: 1,
  fullyParallel: false,
  reporter: [
    ["list"],
    ["html", { outputFolder: "playwright-report", open: "never" }],
  ],
  use: {
    baseURL: process.env.RHDH_BASE_URL,
    headless: isHeadless,
    ignoreHTTPSErrors: true,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
});
