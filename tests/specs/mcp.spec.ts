import { expect, test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import { sendMessage } from "../support/conversation-helper";
import { selectChatModel } from "../support/lightspeed-page";
import {
  closeConfigureServerModal,
  closeMcpSettings,
  getMcpServerRow,
  getMcpServerSwitch,
  MCP_SERVER_NAME,
  openConfigureServerModal,
  openMcpSettingsInMode,
  toggleMcpServer,
} from "../support/mcp-helper";

const MCP_TOOL_CALL_PROMPT =
  "Use the mcp_list_tools tool for server mcp-integration-tools, then respond with exactly: MCP tool call done.";

test.describe("Lightspeed MCP", () => {
  test.describe.configure({ mode: "serial", timeout: 12 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(12 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser));
  });

  test.afterAll(async () => {
    await context?.close();
  });

  async function ensureMcpServerEnabled(serverName: string): Promise<void> {
    const serverSwitch = await getMcpServerSwitch(page, serverName);
    if (await serverSwitch.isChecked()) {
      return;
    }
    await toggleMcpServer(page, serverName);
    await expect(serverSwitch).toBeChecked();
  }

  test("lists configured MCP server in overlay mode", async () => {
    await openMcpSettingsInMode(page, "Overlay");
    const row = await getMcpServerRow(page, MCP_SERVER_NAME);
    const serverSwitch = await getMcpServerSwitch(page, MCP_SERVER_NAME);

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

    await toggleMcpServer(page, MCP_SERVER_NAME);
    await expect
      .poll(async () => toggle.isChecked())
      .toBe(!initiallyEnabled);

    const disabledLabel = row.getByText(/disabled/i);
    await expect
      .poll(async () => disabledLabel.isVisible())
      .toBe(initiallyEnabled);

    await toggleMcpServer(page, MCP_SERVER_NAME);
    await expect
      .poll(async () => toggle.isChecked())
      .toBe(initiallyEnabled);
  });

  // Real backend ships mcp-integration-tools with an organization token
  // (charts/rhdh/values.yaml). Org mode hides #mcp-pat-input — same UI as
  // rhdh-plugins MCP configure modal refactor (#3698).
  test("edit opens configure modal with organization token", async () => {
    await openMcpSettingsInMode(page, "Overlay");
    const modal = await openConfigureServerModal(page, MCP_SERVER_NAME);

    await expect(
      modal.getByRole("heading", {
        name: `${MCP_SERVER_NAME} MCP server settings`,
      }),
    ).toBeVisible();

    await expect(modal.getByText("Status", { exact: true })).toBeVisible();
    // Heading is "Tools (N)"; avoid matching tool names like mcp_list_tools.
    await expect(modal.getByText(/^Tools \(\d+\)$/)).toBeVisible();
    await expect(modal.getByText("Enabled", { exact: true })).toBeVisible();
    await expect(
      modal.getByText("Authentication", { exact: true }),
    ).toBeVisible();

    const organizationTokenRadio = modal.getByRole("radio", {
      name: "Use organization default token",
    });
    const personalTokenRadio = modal.getByRole("radio", {
      name: "Use personal token",
    });

    await expect(organizationTokenRadio).toBeChecked();
    await expect(personalTokenRadio).toBeVisible();
    await expect(page.locator("#mcp-pat-input")).toBeHidden();

    await personalTokenRadio.check();
    const patInput = page.locator("#mcp-pat-input");
    await expect(patInput).toBeVisible();
    await expect(patInput).toHaveAttribute("type", /password/i);

    await closeConfigureServerModal(page);
  });

  test("MCP tool calling renders in chat UI", async () => {
    await openMcpSettingsInMode(page, "Fullscreen");
    await ensureMcpServerEnabled(MCP_SERVER_NAME);
    await closeMcpSettings(page);

    await selectChatModel(page);
    await sendMessage(MCP_TOOL_CALL_PROMPT, page, false);
    await expect(
      page.getByRole("button", { name: /mcp_list_tools/i }).first(),
    ).toBeVisible({ timeout: 60_000 * 15 });
  });
});
