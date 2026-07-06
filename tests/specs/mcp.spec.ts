import { expect, test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { sendMessage } from "../support/conversation-helper";
import { loginViaKeycloakImpersonation } from "../support/auth";
import { openLightspeed } from "../support/test-helper";
import { selectChatModel } from "../support/lightspeed-page";
import {
  closeMcpSettings,
  getMcpServerRow,
  getMcpServerSwitch,
  MCP_SERVER_NAME,
  openConfigureTokenModal,
  openMcpSettingsInMode,
  toggleMcpServer,
  waitForMcpServerPatch,
} from "../support/mcp-helper";

const MCP_TOOL_CALL_PROMPT =
  "Use the mcp_list_tools tool for server mcp-integration-tools, then respond with exactly: MCP tool call done.";

test.describe("Lightspeed MCP", () => {
  test.describe.configure({ mode: "serial", timeout: 7 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(12 * 60 * 1000);

    context = await browser.newContext({
      baseURL: process.env.RHDH_BASE_URL,
      permissions: ["clipboard-read", "clipboard-write"],
      ignoreHTTPSErrors: true,
      locale: "en-US",
      timezoneId: "UTC",
      userAgent:
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    });
    await context.addInitScript(
      "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})",
    );
    page = await context.newPage();
    await loginViaKeycloakImpersonation(page, context);
  });

  test.afterAll(async () => {
    await context?.close();
  });

  async function ensureMcpServerEnabled(serverName: string): Promise<void> {
    const serverSwitch = await getMcpServerSwitch(page, serverName);
    if (await serverSwitch.isChecked()) {
      return;
    }
    const enablePatchPromise = waitForMcpServerPatch(page, serverName);
    await toggleMcpServer(page, serverName);
    const enablePatch = await enablePatchPromise;
    expect(enablePatch.ok()).toBeTruthy();
    await expect(serverSwitch).toBeChecked();
  }

  test("lists configured MCP server in overlay mode", async () => {
    await openMcpSettingsInMode(page, "Overlay");
    const row = await getMcpServerRow(page, MCP_SERVER_NAME);
    const serverSwitch = await getMcpServerSwitch(page, MCP_SERVER_NAME);
    await page.getByRole('columnheader', { name: 'Status' }).click();

    await expect(row.getByText(MCP_SERVER_NAME, { exact: true })).toBeVisible();
    await expect(serverSwitch).toBeEnabled();
    await expect(row.getByText(/token required/i)).toBeHidden();
  });

  test("MCP settings are accessible in dock and fullscreen modes", async () => {
    for (const mode of ["Dock to window", "Fullscreen"] as const) {
      await openMcpSettingsInMode(page, mode);
      const row = await getMcpServerRow(page, MCP_SERVER_NAME);
      await expect(row).toBeVisible();
      await closeMcpSettings(page);
    }
  });

  test("toggling MCP server updates status and can be reverted", async () => {
    await openMcpSettingsInMode(page, "Overlay");
    const row = await getMcpServerRow(page, MCP_SERVER_NAME);
    const toggle = await getMcpServerSwitch(page, MCP_SERVER_NAME);
    await expect(toggle).toBeEnabled();

    const initiallyEnabled = await toggle.isChecked();

    const firstPatchPromise = waitForMcpServerPatch(page, MCP_SERVER_NAME);
    await toggleMcpServer(page, MCP_SERVER_NAME);
    const firstPatch = await firstPatchPromise;
    expect(firstPatch.ok()).toBeTruthy();

    await expect
      .poll(async () => toggle.isChecked())
      .toBe(!initiallyEnabled);

    const disabledLabel = row.getByText(/disabled/i);
    await expect
      .poll(async () => disabledLabel.isVisible())
      .toBe(initiallyEnabled);

    const secondPatchPromise = waitForMcpServerPatch(page, MCP_SERVER_NAME);
    await toggleMcpServer(page, MCP_SERVER_NAME);
    const secondPatch = await secondPatchPromise;
    expect(secondPatch.ok()).toBeTruthy();
    await expect
      .poll(async () => toggle.isChecked())
      .toBe(initiallyEnabled);
  });

  test("clicking edit opens MCP token dialog", async () => {
    await openMcpSettingsInMode(page, "Overlay");
    await openConfigureTokenModal(page, MCP_SERVER_NAME);

    const tokenInput = page.locator("#mcp-pat-input");
    await expect(tokenInput).toBeVisible();
    await expect(tokenInput).toHaveAttribute("type", /password/i);

    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(tokenInput).toBeHidden();
  });

  test("MCP tool calling renders in chat UI", async () => {
    await openMcpSettingsInMode(page, "Fullscreen");
    await ensureMcpServerEnabled(MCP_SERVER_NAME);
    await closeMcpSettings(page);

    await openLightspeed(page);
    await selectChatModel(page);
    await sendMessage(MCP_TOOL_CALL_PROMPT, page, false);

    await expect(
      page.getByRole("button", { name: /mcp_list_tools/i }).first(),
    ).toBeVisible({ timeout: 60_000 });
  });
});
