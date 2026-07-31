import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "@playwright/test";
import dotenv from "dotenv";

dotenv.config({
  path: path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../scripts/private-env",
  ),
  override: false,
  quiet: true,
});

const isHeadless =
  (process.env.PLAYWRIGHT_HEADLESS ?? "true").toLowerCase() !== "false";

export default defineConfig({
  testDir: "./specs",
  testMatch: "**/*.spec.ts",
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
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
});
