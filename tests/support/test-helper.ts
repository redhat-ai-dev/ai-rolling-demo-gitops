import { expect, type Page } from "@playwright/test";

/**
 * Opens /lightspeed and waits for any recognizable Lightspeed shell
 * (chat input, heading, or empty state warning).
 */
export async function openLightspeed(page: Page): Promise<void> {
  await page.goto("/lightspeed", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/lightspeed/, { timeout: 60_000 });

  const chatUi = page
    .locator(".pf-chatbot__messagebox")
    .or(page.getByRole("heading", { name: "Developer Lightspeed" }))
    .or(page.getByTestId("lightspeed-lcore-not-configured"));

  await chatUi.first().waitFor({ state: "visible", timeout: 120_000 });
}
