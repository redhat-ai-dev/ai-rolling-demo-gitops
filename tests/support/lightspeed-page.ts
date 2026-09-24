import { expect, type Page } from "@playwright/test";

export type DisplayMode = "Overlay" | "Dock to window" | "Fullscreen";

/** Preferred chat model; Kind CI may only list the vLLM model. */
export const DEFAULT_CHAT_MODEL =
  process.env.E2E_CHAT_MODEL?.trim() ||
  process.env.VALIDATION_MODEL_NAME?.trim() ||
  "gpt-4o-mini";

/** IA `settings.mcp.label` — renamed from "MCP settings" in 5.3.x (saved prompts). */
export const MCP_SETTINGS_MENU_LABEL = "MCP and Prompt Settings";

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

  // History drawer empty-states are disabled menuitems; the chatbot selector
  // menu uses enabled items (names may include vision tooltip suffixes).
  const enabledModels = page.getByRole("menuitem", { disabled: false });
  if ((await enabledModels.count()) === 0) {
    await dropdown.click();
  }
  await expect(enabledModels.first()).toBeVisible({ timeout: 15_000 });

  const preferred = page.getByRole("menuitem", {
    name: modelName,
    disabled: false,
  });
  if ((await preferred.count()) > 0) {
    await preferred.first().click();
    await expect(dropdown).toContainText(modelName);
    return;
  }

  const fallback = enabledModels.first();
  const selected = ((await fallback.textContent()) ?? "").trim();
  await fallback.click();
  if (selected) {
    await expect(dropdown).toContainText(selected.split(/\s+/)[0] ?? selected);
  }
}

export async function openChatbot(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Open intelligent assistant" }).click();
}

export async function selectDisplayMode(
  page: Page,
  mode: DisplayMode,
): Promise<void> {
  await page.getByRole("button", { name: "Options" }).click();
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
  await expect(page.getByRole("button", { name: "Options" })).toBeVisible();
}

export async function verifyDisplayModeMenuOptions(page: Page): Promise<void> {
  await page.getByRole("button", { name: "Options" }).click();
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
    MCP_SETTINGS_MENU_LABEL,
  ]) {
    await expect(page.getByRole("menuitem", { name })).toBeVisible();
  }
}

export async function expectChatInputAreaVisible(page: Page): Promise<void> {
  await expect(
    page.getByRole("textbox", { name: "Send a message" }),
  ).toBeVisible();
}

export async function expectEmptyChatHistory(page: Page): Promise<void> {
  for (const { name, exact } of [
    { name: "Saved prompts" },
    { name: "Pinned chats" },
    { name: "Chats", exact: true },
  ]) {
    await expect(
      page.getByRole("heading", exact ? { name, exact: true } : { name }),
    ).toBeVisible();
  }

  // Empty-state rows only when lists are empty. Serial suite retries reuse the
  // same Keycloak session, so prior conversation tests may leave chats behind.
  const savedEmpty = page.getByRole("menuitem", { name: "No saved prompts yet" });
  if ((await savedEmpty.count()) > 0) {
    await expect(savedEmpty).toBeVisible();
  }

  const pinnedEmpty = page.getByRole("menuitem", {
    name: "Pin chats to keep them on top",
  });
  if ((await pinnedEmpty.count()) > 0) {
    await expect(pinnedEmpty).toBeVisible();
  }

  const chatsEmpty = page.getByRole("menuitem", { name: "No recent chats" });
  if ((await chatsEmpty.count()) > 0) {
    await expect(chatsEmpty).toBeVisible();
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
