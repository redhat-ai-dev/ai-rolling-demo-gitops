import { request, type BrowserContext, type Page } from "@playwright/test";

type BrowserCookie = {
  name: string;
  value: string;
  domain: string;
  path: string;
  secure: boolean;
  sameSite: "Strict" | "Lax" | "None";
};

type ParsedSetCookie = {
  name: string;
  value: string;
  path: string;
  secure: boolean;
  sameSite: "Strict" | "Lax" | "None";
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Required environment variable '${name}' is not set. Set it before running tests:\n` +
        `  export ${name}=<value>`,
    );
  }
  return value;
}

function parseSetCookieHeader(setCookieHeader: string): ParsedSetCookie {
  const segments = setCookieHeader.split(";").map((segment) => segment.trim());
  const nameValue = segments[0] ?? "";
  const eqIdx = nameValue.indexOf("=");
  if (eqIdx <= 0) {
    throw new Error(`Invalid Set-Cookie header: ${setCookieHeader}`);
  }

  const name = nameValue.slice(0, eqIdx);
  const value = nameValue.slice(eqIdx + 1);
  let path = "/";
  let secure = false;
  let sameSite: "Strict" | "Lax" | "None" = "Lax";

  for (const attribute of segments.slice(1)) {
    const [rawKey, rawValue = ""] = attribute.split("=");
    const key = rawKey.toLowerCase();
    const normalizedValue = rawValue.toLowerCase();
    if (key === "path" && rawValue) {
      path = rawValue;
    } else if (key === "secure") {
      secure = true;
    } else if (key === "samesite") {
      if (normalizedValue === "strict") {
        sameSite = "Strict";
      } else if (normalizedValue === "none") {
        sameSite = "None";
      } else {
        sameSite = "Lax";
      }
    }
  }

  return { name, value, path, secure, sameSite };
}

async function getImpersonationCookies(): Promise<BrowserCookie[]> {
  const rhdhBaseUrl = requireEnv("RHDH_BASE_URL").replace(/\/$/, "");
  const rhdhEnvironment = requireEnv("RHDH_ENVIRONMENT");
  const username = requireEnv("ROLLING_DEMO_TEST_USERNAME");
  const clientId = requireEnv("KEYCLOAK_CLIENT_ID");
  const clientSecret = requireEnv("KEYCLOAK_CLIENT_SECRET");

  const api = await request.newContext({
    ignoreHTTPSErrors: true,
  });

  try {
    const startResp = await api.get(`${rhdhBaseUrl}/api/auth/oidc/start`, {
      params: { env: rhdhEnvironment },
      maxRedirects: 0,
    });

    if (!startResp.ok() && startResp.status() !== 302) {
      throw new Error(
        `Failed /api/auth/oidc/start call: ${startResp.status()} ${startResp.statusText()}`,
      );
    }

    const authUrl = startResp.headers()["location"];
    if (!authUrl) {
      throw new Error("Missing Location header from /api/auth/oidc/start");
    }

    const parsedAuthUrl = new URL(authUrl);
    const origin = `${parsedAuthUrl.protocol}//${parsedAuthUrl.host}`;
    const realmPath = parsedAuthUrl.pathname.split("/protocol")[0];
    const realmName = realmPath.replace(/^\/+|\/+$/g, "").split("/").at(-1);
    const hostname = parsedAuthUrl.hostname;

    if (!realmName) {
      throw new Error(`Unable to derive realm name from auth URL path: ${parsedAuthUrl.pathname}`);
    }

    const tokenResp = await api.post(
      `${origin}${realmPath}/protocol/openid-connect/token`,
      {
        form: {
          grant_type: "client_credentials",
          client_id: clientId,
          client_secret: clientSecret,
        },
      },
    );
    if (!tokenResp.ok()) {
      throw new Error(`Failed to get client token: ${tokenResp.status()} ${await tokenResp.text()}`);
    }
    const tokenPayload = (await tokenResp.json()) as { access_token?: string };
    const token = tokenPayload.access_token;
    if (!token) {
      throw new Error("Token response missing access_token");
    }

    const usersResp = await api.get(`${origin}/auth/admin/realms/${realmName}/users`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { username, exact: "true" },
    });
    if (!usersResp.ok()) {
      throw new Error(`Failed user lookup: ${usersResp.status()} ${await usersResp.text()}`);
    }
    const users = (await usersResp.json()) as Array<{ id: string }>;
    if (!users.length) {
      throw new Error(`User '${username}' not found in realm '${realmName}'`);
    }

    const impersonateResp = await api.post(
      `${origin}/auth/admin/realms/${realmName}/users/${users[0].id}/impersonation`,
      {
        headers: { Authorization: `Bearer ${token}` },
        maxRedirects: 0,
      },
    );
    if (!impersonateResp.ok() && impersonateResp.status() !== 302) {
      throw new Error(
        `Failed impersonation request: ${impersonateResp.status()} ${await impersonateResp.text()}`,
      );
    }

    const setCookieHeaders = impersonateResp
      .headersArray()
      .filter((header) => header.name.toLowerCase() === "set-cookie")
      .map((header) => header.value);

    if (!setCookieHeaders.length) {
      throw new Error("No cookies were returned by Keycloak impersonation endpoint");
    }

    return setCookieHeaders.map((header) => {
      const parsed = parseSetCookieHeader(header);
      return {
        name: parsed.name,
        value: parsed.value,
        domain: hostname,
        path: parsed.path || "/",
        secure: parsed.secure,
        sameSite: parsed.sameSite,
      };
    });
  } finally {
    await api.dispose();
  }
}

export async function loginViaKeycloakImpersonation(
  page: Page,
  context: BrowserContext = page.context(),
): Promise<void> {
  const rhdhBaseUrl = requireEnv("RHDH_BASE_URL").replace(/\/$/, "");
  const cookies = await getImpersonationCookies();
  await context.addCookies(cookies);

  await page.goto(rhdhBaseUrl, { waitUntil: "networkidle" });

  const popupPromise = context.waitForEvent("page", { timeout: 15_000 }).catch(() => null);
  await page.getByRole("button", { name: "Sign in" }).click();
  const popup = await popupPromise;

  if (popup) {
    await popup.waitForLoadState("domcontentloaded");
    await popup.waitForEvent("close", { timeout: 15_000 }).catch(() => {
      /* popup may close before we start waiting */
    });
  }

  await page.waitForLoadState("networkidle");
  await hidePostLoginBannerIfVisible(page);
}

/**
 * Some deployments show a post-login dismissible panel/button.
 * Click it when present so tests start from a consistent UI state.
 */
export async function hidePostLoginBannerIfVisible(
  page: Page,
  timeout = 5_000,
): Promise<void> {
  const hideButton = page.getByRole("button", { name: "Hide" });
  if (await hideButton.isVisible({ timeout })) {
    await hideButton.click();
  }
}
