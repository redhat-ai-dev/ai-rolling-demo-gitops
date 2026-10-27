import { expect, type Page } from "@playwright/test";

function intelligentAssistantShell(page: Page) {
  return page
    .locator(".pf-chatbot__messagebox")
    .or(
      page.getByRole("heading", {
        name: "Developer Hub Intelligent Assistant",
      }),
    )
    .or(page.getByTestId("lightspeed-lcore-not-configured"));
}

/**
 * Opens /intelligent-assistant and waits for any recognizable IA shell
 * (chat input, heading, or empty state warning).
 *
 * Skip goto when the serial suite is already on a live IA page — remounting
 * the same SPA route after a file-upload alert can leave Kind on a blank page.
 */
export async function openLightspeed(page: Page): Promise<void> {
  const chatUi = intelligentAssistantShell(page);

  if (
    /\/intelligent-assistant/.test(page.url()) &&
    (await chatUi.first().isVisible())
  ) {
    return;
  }

  await page.goto("/intelligent-assistant", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/intelligent-assistant/, { timeout: 60_000 });

  try {
    await chatUi.first().waitFor({ state: "visible", timeout: 30_000 });
  } catch {
    await page.reload({ waitUntil: "domcontentloaded" });
    await chatUi.first().waitFor({ state: "visible", timeout: 120_000 });
  }
}
