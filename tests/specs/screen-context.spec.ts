import { test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import { openChatbotSettings } from "../support/chat-management";
import {
  expectConversationArea,
  openChatbot,
  selectDisplayMode,
} from "../support/lightspeed-page";
import {
  disableScreenContextViaKebab,
  enableScreenContextViaKebab,
  expectScreenContextChipHidden,
  expectScreenContextPausedVisible,
  expectScreenContextRecordingVisible,
  expectScreenContextUnavailableVisible,
  pauseScreenContextChip,
  resumeScreenContextChip,
  selectEnableScreenContext,
  verifyEnableScreenContextOption,
} from "../support/screen-context";

/**
 * Deep context / screen-context chip journeys from IA 5.3.x
 * (rhdh-plugins lightspeed.screen-context.test.ts), adapted for Keycloak + Kind.
 */
test.describe("Lightspeed screen context", () => {
  test.describe.configure({ mode: "serial" });

  let context: BrowserContext;
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(10 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser));
  });

  test.afterAll(async () => {
    await context?.close();
  });

  test.beforeEach(async () => {
    await page.goto("/catalog");
    await openChatbot(page);
  });

  test("kebab Enable shows recording chip; Disable hides it", async () => {
    await expectScreenContextChipHidden(page);

    // Verify then click in the same open menu — Escape closes the chatbot panel.
    await openChatbotSettings(page);
    await verifyEnableScreenContextOption(page);
    await selectEnableScreenContext(page);
    await expectScreenContextRecordingVisible(page);

    await disableScreenContextViaKebab(page);
    await expectScreenContextChipHidden(page);
  });

  test("chip pause/resume toggles Context: paused label", async () => {
    await enableScreenContextViaKebab(page);
    await pauseScreenContextChip(page);
    await expectScreenContextPausedVisible(page);

    await resumeScreenContextChip(page);
    await expectScreenContextRecordingVisible(page);

    await disableScreenContextViaKebab(page);
  });

  test("fullscreen shows Context: unavailable", async () => {
    await enableScreenContextViaKebab(page);
    await selectDisplayMode(page, "Fullscreen");
    await expectConversationArea(page, "Fullscreen");

    // Sharing may not persist across the fullscreen remount; re-enable so the
    // unavailable chip can render (do not assert recording chip after enable).
    await openChatbotSettings(page);
    await verifyEnableScreenContextOption(page);
    await selectEnableScreenContext(page);
    await expectScreenContextUnavailableVisible(page);
  });
});
