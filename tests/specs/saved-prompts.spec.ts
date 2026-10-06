import { expect, test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import { SavedPromptsPage } from "../support/saved-prompts-page";

const PROMPT_CONTENT = "Walk me through a safe deployment.";

/**
 * Basic saved-prompts checks ported from overlay intelligent-assistant e2e
 * (live LCORE API, no mocks).
 */
test.describe("Intelligent assistant saved prompts", () => {
  test.describe.configure({ mode: "serial", timeout: 5 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;
  let savedPrompts: SavedPromptsPage;
  let promptName: string;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(10 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser));
    savedPrompts = new SavedPromptsPage(page);
    promptName = `E2E Deploy checklist ${Date.now()}`;
  });

  test.beforeEach(async () => {
    await savedPrompts.openChatShell();
  });

  test.afterAll(async () => {
    await context?.close();
  });

  // Assertions live in SavedPromptsPage helpers.
  /* eslint-disable playwright/expect-expect */
  test("creates a saved prompt from the settings panel", async () => {
    await savedPrompts.openSavedPromptsSettingsTab();
    await savedPrompts.createSavedPrompt(promptName, PROMPT_CONTENT);
    await savedPrompts.expectSavedPromptVisibleInSettings(promptName);
    await savedPrompts.closeSettingsPanel();
  });

  test("shows saved prompts in the chat history sidebar", async () => {
    await savedPrompts.openSavedPromptsHistoryDrawer();
    await savedPrompts.expectSavedPromptsSidebarLoaded(promptName);
  });

  test("applies a saved prompt to the message input from the sidebar", async () => {
    await savedPrompts.openSavedPromptsHistoryDrawer();
    await savedPrompts.applySavedPromptFromSidebar(promptName);
    await savedPrompts.closeSavedPromptsHistoryDrawer();
    await savedPrompts.expectMessageInputValue(PROMPT_CONTENT);
  });

  test("opens saved prompts settings from the sidebar gear control", async () => {
    await savedPrompts.openSavedPromptsSettingsFromSidebarGear();
    await savedPrompts.expectSavedPromptsSettingsPanelVisible();
    await savedPrompts.closeSettingsPanel();
  });

  test("applies a saved prompt via the settings kebab menu", async () => {
    await savedPrompts.openSavedPromptsSettingsTab();
    await savedPrompts.applySavedPromptFromKebab(promptName, "settings");
    await savedPrompts.expectMessageInputValue(PROMPT_CONTENT);
  });

  test("deletes a saved prompt from the settings kebab menu", async () => {
    await savedPrompts.openSavedPromptsSettingsTab();
    await savedPrompts.deleteSavedPromptFromKebab(promptName, "settings");
    await savedPrompts.expectSavedPromptHiddenInSettings(promptName);
    await savedPrompts.closeSettingsPanel();
    await savedPrompts.openSavedPromptsHistoryDrawer();
    await expect(savedPrompts.savedPromptSidebarItem(promptName)).toBeHidden({
      timeout: 15_000,
    });
  });
  /* eslint-enable playwright/expect-expect */
});
