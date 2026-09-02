import { expect, type Locator, type Page } from "@playwright/test";
import {
  entityPagePath,
  type AiModelServerApiEntity,
} from "./kserve-connector";

export async function openCatalogIndex(page: Page): Promise<void> {
  await page.goto("/catalog", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/catalog/, { timeout: 60_000 });
}

export async function openEntityPage(
  page: Page,
  entity: AiModelServerApiEntity,
): Promise<void> {
  await page.goto(entityPagePath(entity), { waitUntil: "domcontentloaded" });
  await expect(
    page.getByText(entity.metadata.name, { exact: false }).first(),
  ).toBeVisible({ timeout: 60_000 });
}

export async function openExtensionsInstalledPackages(
  page: Page,
): Promise<boolean> {
  await page.goto("/extensions/installed-packages", {
    waitUntil: "domcontentloaded",
  });
  if (!/\/extensions/.test(page.url())) {
    return false;
  }
  return true;
}

export function entityDocsTab(page: Page): Locator {
  return page
    .getByRole("tab", { name: /docs/i })
    .or(page.getByRole("link", { name: /^docs$/i }));
}
