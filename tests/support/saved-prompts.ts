import { expect, type Locator, type Page } from "@playwright/test";
import { MCP_SETTINGS_MENU_LABEL } from "./lightspeed-page";

/**
 * Saved prompts helpers for the real Kind/cluster IA stack (no API mocks).
 * Locators follow rhdh-plugins SavedPromptsPage / English `settings.*` strings.
 */

function chatbotRegion(page: Page): Locator {
  return page.getByLabel("Chatbot", { exact: true });
}

/** History drawer panel (same shell as chat-management / sidebar helpers). */
function savedPromptsHistoryDrawer(page: Page): Locator {
  return page.locator(".pf-v6-c-drawer__panel-main");
}

function savedPromptsMenu(page: Page): Locator {
  return savedPromptsHistoryDrawer(page).getByRole("menu", {
    name: /Saved prompts/,
  });
}

export function savedPromptSidebarItem(
  page: Page,
  promptName: string,
): Locator {
  // Items may use aria-label "Options" like chat rows; match on visible title.
  return savedPromptsMenu(page)
    .locator("li.pf-chatbot__menu-item")
    .filter({ hasText: promptName });
}

export async function expectSavedPromptsSidebarEmpty(
  page: Page,
): Promise<void> {
  await expect(
    savedPromptsMenu(page).getByRole("menuitem", {
      name: "No saved prompts yet",
    }),
  ).toBeVisible({ timeout: 15_000 });
}

export async function expectSavedPromptInSidebar(
  page: Page,
  promptName: string,
): Promise<void> {
  await expect(savedPromptSidebarItem(page, promptName)).toBeVisible({
    timeout: 15_000,
  });
}

export async function applySavedPromptFromSidebar(
  page: Page,
  promptName: string,
): Promise<void> {
  await expectSavedPromptInSidebar(page, promptName);
  await savedPromptSidebarItem(page, promptName).click();
}

/** Opens Settings → Saved prompts tab via the Options kebab. */
export async function openSavedPromptsSettingsTab(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Options" }).click();
  await page.getByRole("menuitem", { name: MCP_SETTINGS_MENU_LABEL }).click();
  await page
    .getByRole("button", { name: "Saved prompts", exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: "+ New prompt" }),
  ).toBeVisible();
}

export async function closeSavedPromptsSettings(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Close MCP settings" }).click();
}

export async function createSavedPrompt(
  page: Page,
  name: string,
  content: string,
): Promise<void> {
  await page.getByRole("button", { name: "+ New prompt" }).click();
  await page.getByPlaceholder("Prompt title").fill(name);
  await page.getByPlaceholder("Prompt content").fill(content);
  await chatbotRegion(page)
    .getByRole("button", { name: "Save", exact: true })
    .click();
}

export async function expectSavedPromptVisibleInSettings(
  page: Page,
  name: string,
): Promise<void> {
  await expect(
    chatbotRegion(page)
      .getByTestId("saved-prompts-list")
      .getByText(name, { exact: true }),
  ).toBeVisible({ timeout: 15_000 });
}

export async function expectEmptySavedPromptsSettings(
  page: Page,
): Promise<void> {
  const emptyState = chatbotRegion(page).getByTestId("saved-prompts-empty-state");
  await expect(emptyState).toBeVisible({ timeout: 15_000 });
  await expect(
    emptyState.getByText("No prompts", { exact: true }),
  ).toBeVisible();
  await expect(
    emptyState.getByRole("button", { name: "+ New prompt" }),
  ).toBeVisible();
}

function savedPromptKebabInSettings(page: Page, promptName: string): Locator {
  return chatbotRegion(page).getByRole("button", {
    name: `Actions for ${promptName}`,
  });
}

export async function deleteSavedPromptFromSettings(
  page: Page,
  promptName: string,
): Promise<void> {
  await savedPromptKebabInSettings(page, promptName).click();
  await page.getByRole("menuitem", { name: "Delete", exact: true }).click();
  await page
    .getByRole("dialog", { name: `Delete '${promptName}'?` })
    .getByRole("button", { name: "Delete", exact: true })
    .click();
}

export async function expectSavedPromptHiddenInSettings(
  page: Page,
  name: string,
): Promise<void> {
  await expect(
    chatbotRegion(page)
      .getByTestId("saved-prompts-list")
      .getByText(name, { exact: true }),
  ).toBeHidden({ timeout: 15_000 });
}

export async function applySavedPromptFromSettingsKebab(
  page: Page,
  promptName: string,
): Promise<void> {
  await savedPromptKebabInSettings(page, promptName).click();
  await page
    .getByRole("menuitem", { name: "Apply in input box", exact: true })
    .click();
  await closeSavedPromptsSettings(page);
}
