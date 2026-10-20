import { expect, type Page } from "@playwright/test";
import { openChatbotSettings } from "./chat-management";

/** Either recording or paused chip (`aria-label` starts with Pause/Resume). */
export const screenContextChip = (page: Page) =>
  page.getByLabel(/^(Pause|Resume) screen context/);

export const screenContextRecordingChip = (page: Page) =>
  page.getByLabel(/^Pause screen context/);

export const screenContextPausedChip = (page: Page) =>
  page.getByLabel(/^Resume screen context/);

export async function expectScreenContextChipHidden(page: Page): Promise<void> {
  await expect(screenContextChip(page)).toHaveCount(0);
}

export async function expectScreenContextRecordingVisible(
  page: Page,
): Promise<void> {
  await expect(screenContextRecordingChip(page)).toBeVisible();
}

export async function expectScreenContextPausedVisible(
  page: Page,
): Promise<void> {
  await expect(screenContextPausedChip(page)).toBeVisible();
}

export async function verifyEnableScreenContextOption(
  page: Page,
): Promise<void> {
  await expect(
    page.getByRole("menuitem", {
      name: "Enable screen context Screen context sharing is currently disabled",
    }),
  ).toBeVisible();
}

export async function verifyDisableScreenContextOption(
  page: Page,
): Promise<void> {
  await expect(
    page.getByRole("menuitem", {
      name: "Disable screen context Screen context sharing is currently enabled",
    }),
  ).toBeVisible();
}

export async function selectEnableScreenContext(page: Page): Promise<void> {
  await page.getByRole("menuitem", { name: "Enable screen context" }).click();
}

export async function selectDisableScreenContext(page: Page): Promise<void> {
  await page.getByRole("menuitem", { name: "Disable screen context" }).click();
}

export async function enableScreenContextViaKebab(page: Page): Promise<void> {
  await openChatbotSettings(page);
  await verifyEnableScreenContextOption(page);
  await selectEnableScreenContext(page);
  await expectScreenContextRecordingVisible(page);
}

export async function disableScreenContextViaKebab(page: Page): Promise<void> {
  await openChatbotSettings(page);
  await verifyDisableScreenContextOption(page);
  await selectDisableScreenContext(page);
  await expectScreenContextChipHidden(page);
}

export async function pauseScreenContextChip(page: Page): Promise<void> {
  await screenContextRecordingChip(page).click();
}

export async function resumeScreenContextChip(page: Page): Promise<void> {
  await screenContextPausedChip(page).click();
}
