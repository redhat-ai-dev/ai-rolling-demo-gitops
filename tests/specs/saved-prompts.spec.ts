import { test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import { expectChatInputValue } from "../support/conversation-helper";
import {
  closeChatHistoryDrawer,
  openChatbot,
  openChatHistoryDrawer,
} from "../support/lightspeed-page";
import {
  applySavedPromptFromSettingsKebab,
  applySavedPromptFromSidebar,
  createSavedPrompt,
  deleteSavedPromptFromSettings,
  expectEmptySavedPromptsSettings,
  expectSavedPromptHiddenInSettings,
  expectSavedPromptInSidebar,
  expectSavedPromptVisibleInSettings,
  expectSavedPromptsSidebarEmpty,
  openSavedPromptsSettingsTab,
  closeSavedPromptsSettings,
} from "../support/saved-prompts";

/**
 * Saved prompts flows from IA 5.3.x (rhdh-plugins lightspeed.saved-prompts.test.ts),
 * adapted for the real Kind/cluster backend (no Playwright route mocks).
 */
test.describe("Lightspeed saved prompts", () => {
  test.describe.configure({ mode: "serial", timeout: 12 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;

  const promptName = `E2E deploy checklist ${Date.now()}`;
  const promptContent =
    "List the first three steps for a production Kubernetes rollout.";

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(12 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser));
  });

  test.afterAll(async () => {
    await context?.close();
  });

  test.beforeEach(async () => {
    await page.goto("/catalog");
    await openChatbot(page);
  });

  test("creates a saved prompt from settings", async () => {
    await openSavedPromptsSettingsTab(page);
    await createSavedPrompt(page, promptName, promptContent);
    await expectSavedPromptVisibleInSettings(page, promptName);
    await closeSavedPromptsSettings(page);
  });

  test("lists the saved prompt in the chat history sidebar", async () => {
    await openChatHistoryDrawer(page);
    await expectSavedPromptInSidebar(page, promptName);
    await closeChatHistoryDrawer(page);
  });

  test("applies a saved prompt to the message input from the sidebar", async () => {
    await openChatHistoryDrawer(page);
    await applySavedPromptFromSidebar(page, promptName);
    await closeChatHistoryDrawer(page);
    await expectChatInputValue(page, promptContent);
  });

  test("applies a saved prompt via the settings kebab menu", async () => {
    await page.getByRole("textbox", { name: "Send a message" }).fill("");
    await openSavedPromptsSettingsTab(page);
    await applySavedPromptFromSettingsKebab(page, promptName);
    await expectChatInputValue(page, promptContent);
  });

  test("deletes a saved prompt from the settings kebab menu", async () => {
    await openSavedPromptsSettingsTab(page);
    await deleteSavedPromptFromSettings(page, promptName);
    await expectSavedPromptHiddenInSettings(page, promptName);
    await expectEmptySavedPromptsSettings(page);
    await closeSavedPromptsSettings(page);

    await openChatHistoryDrawer(page);
    await expectSavedPromptsSidebarEmpty(page);
    await closeChatHistoryDrawer(page);
  });
});
