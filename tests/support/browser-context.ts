import type { Browser, BrowserContext, Page } from "@playwright/test";
import { loginViaKeycloakImpersonation } from "./auth";

/** Shared browser context options for serial E2E suites. */
export const E2E_BROWSER_CONTEXT_OPTIONS = {
  baseURL: process.env.RHDH_BASE_URL,
  permissions: ["clipboard-read", "clipboard-write"] as const,
  ignoreHTTPSErrors: true,
  locale: "en-US",
  timezoneId: "UTC",
  userAgent:
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
};

/**
 * Creates a browser context + page and logs in via Keycloak impersonation.
 * Call from `test.beforeAll`; close `context` in `test.afterAll`.
 */
export async function createAuthenticatedSession(
  browser: Browser,
  options?: { onPage?: (page: Page) => void },
): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({
    ...E2E_BROWSER_CONTEXT_OPTIONS,
    permissions: [...E2E_BROWSER_CONTEXT_OPTIONS.permissions],
  });
  await context.addInitScript(
    "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})",
  );
  const page = await context.newPage();
  options?.onPage?.(page);
  await loginViaKeycloakImpersonation(page, context);
  return { context, page };
}
