import { expect, type Page } from "@playwright/test";

/**
 * Opens /intelligent-assistant and waits for any recognizable Lightspeed shell
 * (chat input, heading, or empty state warning). Reloads once on timeout —
 * Kind CI occasionally lands on a blank shell after navigation.
 */
export async function openLightspeed(page: Page): Promise<void> {
  await page.goto("/intelligent-assistant", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/intelligent-assistant/, { timeout: 60_000 });

  const chatUi = () =>
    page
      .locator(".pf-chatbot__messagebox")
      .or(
        page.getByRole("heading", {
          name: "Developer Hub Intelligent Assistant",
        }),
      )
      .or(page.getByTestId("lightspeed-lcore-not-configured"));

  try {
    await chatUi().first().waitFor({ state: "visible", timeout: 60_000 });
  } catch {
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(page).toHaveURL(/\/intelligent-assistant/, { timeout: 60_000 });
    await chatUi().first().waitFor({ state: "visible", timeout: 120_000 });
  }
}
