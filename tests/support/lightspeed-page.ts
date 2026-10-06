import { expect, type Page } from "@playwright/test";

export type DisplayMode = "Overlay" | "Dock to window" | "Fullscreen";

/** Default chat model for e2e tests (CI uses OpenAI gpt-4o-mini). */
export const DEFAULT_CHAT_MODEL = "gpt-4o-mini";

export function chatModelSelector(page: Page) {
  return page.getByRole("button", { name: "Chatbot selector" });
}

/** Opens the model dropdown and selects a model; no-op if already selected. */
export async function selectChatModel(
  page: Page,
  modelName: string = DEFAULT_CHAT_MODEL,
): Promise<void> {
  const dropdown = chatModelSelector(page);
  await expect(dropdown).toBeVisible({ timeout: 60_000 });

  if ((await dropdown.textContent())?.includes(modelName)) {
    return;
  }

  const menuitem = page.getByRole("menuitem", { name: modelName });
  if (!(await menuitem.isVisible())) {
    await dropdown.click();
  }
  await menuitem.click();
  await expect(dropdown).toContainText(modelName);
}

export async function openChatbot(page: Page): Promise<void> {
  const chatbot = page.getByLabel("Chatbot", { exact: true });
  if (await chatbot.isVisible().catch(() => false)) {
    return;
  }

  const closeFab = page.getByRole("button", {
    name: "Close intelligent assistant",
  });
  if (!(await closeFab.isVisible().catch(() => false))) {
    await page
      .getByRole("button", { name: "Open intelligent assistant" })
      .click();
  }
  await expect(chatbot).toBeVisible({ timeout: 30_000 });
}

function chatbotHeaderOptions(page: Page) {
  return page
    .locator(".pf-chatbot__header")
    .getByRole("button", { name: "Options" });
}

export async function selectDisplayMode(
  page: Page,
  mode: DisplayMode,
): Promise<void> {
  await chatbotHeaderOptions(page).click();
  await page.getByRole("menuitem", { name: mode }).click();
}

export async function openChatHistoryDrawer(page: Page): Promise<void> {
  const chatHistoryMenu = page.getByRole("button", {
    name: "Chat history menu",
  });
  const expandHistory = page.getByRole("button", {
    name: "Expand chat history",
  });

  if (await chatHistoryMenu.isVisible()) {
    await chatHistoryMenu.click();
  } else if (await expandHistory.isVisible()) {
    await expandHistory.click();
  }
}

export async function closeChatHistoryDrawer(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Close drawer panel" }).click();
}

export async function expectRhdhContentVisible(
  page: Page,
  visible = true,
): Promise<void> {
  const shell = page
    .getByText(/welcome back!/i)
    .or(page.getByText("My Org Catalog"));

  if (visible) {
    await expect(shell).toBeVisible({ timeout: 30_000 });
  } else {
    await expect(shell).toBeHidden({ timeout: 30_000 });
  }
}

/** Opens Lightspeed chatbot in fullscreen from the RHDH shell (avoids /lightspeed route). */
export async function openChatbotFullscreen(page: Page): Promise<void> {
  await expectRhdhContentVisible(page);
  await openChatbot(page);
  await selectDisplayMode(page, "Fullscreen");
}

/** Opens fullscreen chatbot from the RHDH shell and selects the default model. */
export async function openChatbotFullscreenWithModel(
  page: Page,
  modelName: string = DEFAULT_CHAT_MODEL,
): Promise<void> {
  await openChatbotFullscreen(page);
  await selectChatModel(page, modelName);
}

export async function expectChatbotControlsVisible(page: Page): Promise<void> {
  await expect(page.locator(".pf-chatbot__header")).toBeVisible();
  await expect(chatbotHeaderOptions(page)).toBeVisible();
}

export async function verifyDisplayModeMenuOptions(page: Page): Promise<void> {
  await chatbotHeaderOptions(page).click();
  const settingsMenu = page
    .getByRole("menu")
    .filter({
      has: page.getByRole("menuitem", { name: "Display mode" }),
    })
    .first();

  await expect(settingsMenu).toBeVisible();
  await expect(
    settingsMenu.getByRole("menuitem", { name: "Display mode" }),
  ).toBeDisabled();

  for (const name of ["Overlay", "Dock to window", "Fullscreen"]) {
    await expect(settingsMenu.getByRole("menuitem", { name })).toBeVisible();
  }

  for (const name of [
    "Disable pinned chats Pinned chats are currently enabled",
    "Disable saved prompts Saved prompts are currently enabled",
    "MCP and Prompt Settings",
  ]) {
    await expect(page.getByRole("menuitem", { name })).toBeVisible();
  }

  await page.keyboard.press("Escape");
}

export async function expectChatInputAreaVisible(page: Page): Promise<void> {
  await expect(
    page.getByRole("textbox", { name: "Send a message" }),
  ).toBeVisible();
}

export async function expectEmptyChatHistory(page: Page): Promise<void> {
  await expect(
    page.getByRole("heading", { name: /Saved prompts/ }),
  ).toBeVisible();
  await expect(
    page
      .locator(".lightspeed-saved-prompts-group")
      .getByRole("menuitem", { name: "No saved prompts yet" }),
  ).toBeVisible();

  for (const { name, exact } of [
    { name: "Pinned chats" },
    { name: "Chats", exact: true },
  ]) {
    await expect(
      page.getByRole("heading", exact ? { name, exact: true } : { name }),
    ).toBeVisible();
  }

  for (const name of ["Pin chats to keep them on top", "No recent chats"]) {
    await expect(page.getByRole("menuitem", { name })).toBeVisible();
  }
}

export async function expectConversationArea(
  page: Page,
  mode: DisplayMode,
): Promise<void> {
  const messageLog = page.getByLabel("Scrollable message log");
  const expectedDisplayName = process.env.RHDH_DISPLAY_NAME?.trim();

  await expect(
    messageLog.getByRole("heading", { name: /Info alert: Important/i }),
  ).toBeVisible();
  await expect(messageLog.getByText(/AI technology/)).toBeVisible();
  const greetingHeading = messageLog.getByRole("heading", { level: 1 });
  if (expectedDisplayName) {
    await expect(greetingHeading).toContainText(`Hello, ${expectedDisplayName}`);
  } else {
    // In real clusters the greeting uses the authenticated profile display name.
    await expect(greetingHeading).toContainText(/Hello,\s+/i);
  }
  await expect(greetingHeading).toContainText(/How can I help you today\?/i);

  const promptButtons = messageLog.getByRole("button");
  const promptCount = await promptButtons.count();
  // Prompt cards can be absent when a prior conversation is restored.
  if (promptCount > 0) {
    expect(promptCount).toBeGreaterThanOrEqual(1);
    if (mode === "Dock to window") {
      expect(promptCount).toBeGreaterThanOrEqual(2);
    } else if (mode === "Fullscreen") {
      expect(promptCount).toBeGreaterThanOrEqual(3);
    }
  }
}
