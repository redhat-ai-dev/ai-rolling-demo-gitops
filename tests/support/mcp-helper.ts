import { expect, type Locator, type Page } from "@playwright/test";
import {
  openChatbot,
  selectDisplayMode,
  type DisplayMode,
} from "./lightspeed-page";

export const MCP_SERVER_NAME = "mcp-integration-tools";
const MCP_SERVERS_LOADING_TEXT = "Loading MCP servers...";

function getMcpSettingsTable(page: Page): Locator {
  return page
    .locator("table[aria-label*='MCP'], table[aria-label*='mcp']")
    .first();
}

async function openMcpSettings(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Options" }).click();
  await page.getByRole("menuitem", { name: "MCP settings" }).click();
}

async function closeMcpSettingsIfOpen(page: Page): Promise<void> {
  const closeMcpSettingsButton = page.getByRole("button", {
    name: /close mcp settings/i,
  });
  if (await closeMcpSettingsButton.isVisible({ timeout: 2_000 })) {
    await closeMcpSettingsButton.click();
  }
}

async function ensureChatbotIsOpen(page: Page): Promise<void> {
  const optionsButton = page.getByRole("button", { name: "Options" });
  if (await optionsButton.isVisible({ timeout: 2_000 })) {
    return;
  }

  const openLightspeedButton = page.getByRole("button", {
    name: "Open intelligent assistant",
  });
  if (await openLightspeedButton.isVisible({ timeout: 2_000 })) {
    await openChatbot(page);
    await expect(optionsButton).toBeVisible();
    return;
  }

  await page.goto("/");
  await openChatbot(page);
  await expect(optionsButton).toBeVisible();
}

export async function openMcpSettingsInMode(
  page: Page,
  mode: DisplayMode,
): Promise<void> {
  await closeMcpSettingsIfOpen(page);
  await ensureChatbotIsOpen(page);
  await selectDisplayMode(page, mode);
  await openMcpSettings(page);

  const table = getMcpSettingsTable(page);
  await expect(table).toBeVisible();
  await table
    .getByRole("gridcell", {
      name: MCP_SERVERS_LOADING_TEXT,
      exact: true,
    })
    .waitFor({ state: "hidden", timeout: 30_000 });
}

export async function closeMcpSettings(page: Page): Promise<void> {
  const closeMcpSettingsButton = page.getByRole("button", {
    name: /close mcp settings/i,
  });
  await expect(closeMcpSettingsButton).toBeVisible();
  await closeMcpSettingsButton.click();
}

export async function getMcpServerRow(
  page: Page,
  serverName: string,
): Promise<Locator> {
  const row = getMcpSettingsTable(page)
    .getByRole("row")
    .filter({ has: page.getByText(serverName, { exact: true }) })
    .first();
  await expect(row).toBeVisible();
  return row;
}

export async function getMcpServerSwitch(
  page: Page,
  serverName: string,
): Promise<Locator> {
  const row = await getMcpServerRow(page, serverName);
  const labeledToggle = row.getByRole("switch", {
    name: `Toggle ${serverName}`,
    exact: true,
  });
  if (await labeledToggle.isVisible({ timeout: 2_000 })) {
    return labeledToggle;
  }

  const toggle = row.getByRole("switch").first();
  await expect(toggle).toBeVisible();
  return toggle;
}

export async function toggleMcpServer(
  page: Page,
  serverName: string,
): Promise<void> {
  const row = await getMcpServerRow(page, serverName);
  const toggleCell = row.getByRole("gridcell", {
    name: `Toggle ${serverName}`,
    exact: true,
  });

  if (await toggleCell.isVisible({ timeout: 2_000 })) {
    await toggleCell.locator("span").first().click();
    return;
  }

  const toggle = await getMcpServerSwitch(page, serverName);
  await toggle.click();
}

/** Configure-server modal (token and org-credential flows). */
export function mcpConfigureModal(page: Page): Locator {
  return page
    .locator("[role='dialog'], .pf-v6-c-modal-box")
    .filter({ has: page.locator("#mcp-configure-modal-body") });
}

export async function openConfigureServerModal(
  page: Page,
  serverName: string,
): Promise<Locator> {
  const row = await getMcpServerRow(page, serverName);
  const editButton = row.getByRole("button", {
    name: `Edit ${serverName}`,
    exact: true,
  });
  if (await editButton.isVisible({ timeout: 2_000 })) {
    await editButton.click();
  } else {
    await row.getByRole("button").last().click();
  }

  const modal = mcpConfigureModal(page);
  await expect(modal).toBeVisible();
  return modal;
}

export async function closeConfigureServerModal(page: Page): Promise<void> {
  const modal = mcpConfigureModal(page);
  await modal.getByRole("button", { name: "Cancel" }).click();
  await expect(modal).toBeHidden();
}
