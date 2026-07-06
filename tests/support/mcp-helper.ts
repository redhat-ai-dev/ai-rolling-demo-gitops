import {
  expect,
  type Locator,
  type Page,
  type Response,
} from "@playwright/test";
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
  await page.getByRole("button", { name: "Chatbot options" }).click();
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
  const optionsButton = page.getByRole("button", { name: "Chatbot options" });
  if (await optionsButton.isVisible({ timeout: 2_000 })) {
    return;
  }

  const openLightspeedButton = page.getByRole("button", {
    name: "Open Lightspeed",
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

export async function waitForMcpServerPatch(
  page: Page,
  serverName: string,
): Promise<Response> {
  return page.waitForResponse(
    (response) =>
      response.request().method() === "PATCH" &&
      response
        .url()
        .includes(
          `/api/lightspeed/mcp-servers/${encodeURIComponent(serverName)}`,
        ),
  );
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

export async function openConfigureTokenModal(
  page: Page,
  serverName: string,
): Promise<void> {
  const row = await getMcpServerRow(page, serverName);
  await row.getByRole("button").last().click();
  await expect(page.locator("#mcp-pat-input")).toBeVisible();
}
