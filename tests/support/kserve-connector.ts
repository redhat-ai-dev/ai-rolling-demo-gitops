import { expect, test, type Page } from "@playwright/test";

export const KSERVE_CONNECTOR_LIST_PATH = "/api/kserve-kubeflow-connector/list";

export const CONNECTOR_PACKAGE_SUBSTRINGS = [
  "kserve-kubeflow-connector",
  "catalog-backend-module-model-catalog",
  "catalog-techdoc-url-reader",
  "catalog-backend-module-ai-model-server",
] as const;

export const LEGACY_SIDECAR_NAMES = [
  "storage-rest",
  "rhoai-normalizer",
  "model-catalog-location-service",
] as const;

export const LEGACY_SIDECAR_LOCATION = "localhost:9090";

/** Catalog IDs set on tests/fixtures/kserve InferenceServices. */
export const FIXTURE_CATALOG_SOURCE = "kserve-qe";
export const FIXTURE_CATALOG_MODEL = "sklearn-iris";

/** Expected AiModelServerAPI spec for sklearn-iris-overrides. */
export const OVERRIDE_ENTITY_NAME_SUBSTRING = "sklearn-iris-overrides";
export const OVERRIDE_SYSTEM = "kserve-qe-system";
export const OVERRIDE_SERVER_TYPE = "openai-v1";
export const OVERRIDE_DEFAULT_MODEL = "sklearn-iris-primary";
export const OVERRIDE_AVAILABLE_MODELS = [
  "sklearn-iris-primary",
  "sklearn-iris-secondary",
] as const;
export const OVERRIDE_OWNER_SUBSTRING = "team-rhdhpai";
export const OVERRIDE_LIFECYCLE = "experimental";

export type CatalogLink = {
  title: string;
  url: string;
};

export type AiModelServerApiEntity = {
  apiVersion: string;
  kind: string;
  metadata: {
    name: string;
    namespace?: string;
    description?: string;
    tags?: string[];
    annotations?: Record<string, string>;
    links?: CatalogLink[];
  };
  spec: {
    type?: string;
    lifecycle?: string;
    owner?: string;
    system?: string;
    serverType?: string;
    serverUrl?: string;
    requiresApiKey?: boolean;
    models?: {
      available?: string[];
      default?: string;
    };
  };
};

type CatalogByQueryResponse = {
  items?: Array<{ entity?: AiModelServerApiEntity }>;
};

type AuthGetResult = {
  status: number;
  text: string;
};

const capturedIdentityTokens = new WeakMap<Page, string>();

export function isKserveE2eRequired(): boolean {
  return (process.env.KSERVE_E2E ?? "").toLowerCase() === "true";
}

function tokenFromAuthPayload(json: unknown): string | undefined {
  if (!json || typeof json !== "object") {
    return undefined;
  }
  const record = json as Record<string, unknown>;
  const identity = record.backstageIdentity as
    | Record<string, unknown>
    | undefined;
  const provider = record.providerInfo as Record<string, unknown> | undefined;
  for (const candidate of [
    identity?.token,
    record.token,
    provider?.idToken,
    provider?.accessToken,
  ]) {
    if (typeof candidate === "string" && candidate.startsWith("eyJ")) {
      return candidate;
    }
  }
  return undefined;
}

function tokenFromAuthorizationHeader(
  headers: Record<string, string>,
): string | undefined {
  const auth = headers.authorization ?? headers.Authorization ?? "";
  const match = /^Bearer\s+(\S+)/i.exec(auth);
  const token = match?.[1];
  return token?.startsWith("eyJ") ? token : undefined;
}

/**
 * Capture the identity token the UI already sends after Sign in.
 * Playwright's page.request does not add that header automatically.
 */
export function attachIdentityTokenCapture(page: Page): void {
  page.on("request", (request) => {
    const token = tokenFromAuthorizationHeader(request.headers());
    if (token) {
      capturedIdentityTokens.set(page, token);
    }
  });
  page.on("response", (response) => {
    void (async () => {
      if (!/\/api\/auth\/oidc\/(refresh|session)/.test(response.url())) {
        return;
      }
      if (!response.ok()) {
        return;
      }
      try {
        const token = tokenFromAuthPayload(await response.json());
        if (token) {
          capturedIdentityTokens.set(page, token);
        }
      } catch {
        /* not a JSON auth payload */
      }
    })();
  });
}

/**
 * Backstage plugin APIs require an identity token. Prefer a header the UI
 * already sent; fall back to oidc refresh/session and browser storage.
 */
export async function getBackstageIdentityToken(
  page: Page,
): Promise<string | undefined> {
  const captured = capturedIdentityTokens.get(page);
  if (captured) {
    return captured;
  }

  const env = process.env.RHDH_ENVIRONMENT ?? "production";
  const fromPage = await page.evaluate(async (oidcEnv) => {
    const tokenFromJson = (json: unknown): string | undefined => {
      if (!json || typeof json !== "object") {
        return undefined;
      }
      const record = json as Record<string, unknown>;
      const identity = record.backstageIdentity as
        | Record<string, unknown>
        | undefined;
      const provider = record.providerInfo as
        | Record<string, unknown>
        | undefined;
      for (const candidate of [
        identity?.token,
        record.token,
        provider?.idToken,
        provider?.accessToken,
      ]) {
        if (typeof candidate === "string" && candidate.startsWith("eyJ")) {
          return candidate;
        }
      }
      return undefined;
    };

    const tokenFromStore = (storage: Storage): string | undefined => {
      for (let i = 0; i < storage.length; i += 1) {
        const key = storage.key(i);
        if (!key) {
          continue;
        }
        const value = storage.getItem(key) ?? "";
        try {
          const token = tokenFromJson(JSON.parse(value));
          if (token) {
            return token;
          }
        } catch {
          if (value.startsWith("eyJ")) {
            return value;
          }
        }
      }
      return undefined;
    };

    const sessionUrls = [
      `/api/auth/oidc/refresh?optional&env=${encodeURIComponent(oidcEnv)}`,
      `/api/auth/oidc/refresh?env=${encodeURIComponent(oidcEnv)}`,
      "/api/auth/oidc/session",
      `/api/auth/oidc/session?env=${encodeURIComponent(oidcEnv)}`,
    ];
    for (const url of sessionUrls) {
      try {
        const resp = await fetch(url, { credentials: "include" });
        if (!resp.ok) {
          continue;
        }
        const token = tokenFromJson(await resp.json());
        if (token) {
          return token;
        }
      } catch {
        /* try next */
      }
    }

    return tokenFromStore(localStorage) ?? tokenFromStore(sessionStorage);
  }, env);

  if (fromPage) {
    capturedIdentityTokens.set(page, fromPage);
  }
  return fromPage;
}

export async function authenticatedGet(
  page: Page,
  path: string,
  searchParams?: Record<string, string>,
): Promise<AuthGetResult> {
  const token = await getBackstageIdentityToken(page);
  const headers: Record<string, string> = {};
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await page.request.get(path, {
    headers,
    params: searchParams,
  });
  if (response.status() !== 401) {
    return { status: response.status(), text: await response.text() };
  }

  const url = new URL(path, page.url());
  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      url.searchParams.set(key, value);
    }
  }
  return page.evaluate(
    async ({ href, bearer }) => {
      const fetchHeaders: Record<string, string> = {};
      if (bearer) {
        fetchHeaders.Authorization = `Bearer ${bearer}`;
      }
      const resp = await fetch(href, {
        credentials: "include",
        headers: fetchHeaders,
      });
      return { status: resp.status, text: await resp.text() };
    },
    { href: url.toString(), bearer: token ?? "" },
  );
}

function parseJson<T>(text: string): T | undefined {
  try {
    return JSON.parse(text) as T;
  } catch {
    return undefined;
  }
}

export async function fetchConnectorDiscovery(
  page: Page,
): Promise<{ status: number; uris: string[] }> {
  const response = await authenticatedGet(page, KSERVE_CONNECTOR_LIST_PATH);
  const body = parseJson<{ uris?: string[] }>(response.text);
  return { status: response.status, uris: body?.uris ?? [] };
}

export async function fetchAiModelServerEntities(
  page: Page,
): Promise<AiModelServerApiEntity[]> {
  const byQuery = await authenticatedGet(
    page,
    "/api/catalog/entities/by-query",
    { filter: "kind=aimodelserverapi", limit: "100" },
  );
  if (byQuery.status >= 200 && byQuery.status < 300) {
    const body = parseJson<CatalogByQueryResponse>(byQuery.text);
    if (Array.isArray(body?.items)) {
      return body.items
        .map((item) => item.entity)
        .filter((entity): entity is AiModelServerApiEntity => Boolean(entity));
    }
  }

  const legacy = await authenticatedGet(page, "/api/catalog/entities", {
    filter: "kind=AiModelServerAPI",
  });
  if (legacy.status < 200 || legacy.status >= 300) {
    throw new Error(
      `Catalog API failed (${legacy.status}): ${legacy.text.slice(0, 300)}`,
    );
  }
  const entities = parseJson<AiModelServerApiEntity[]>(legacy.text);
  return Array.isArray(entities) ? entities : [];
}

export async function fetchCatalogLocationsBody(page: Page): Promise<string> {
  const response = await authenticatedGet(page, "/api/catalog/locations");
  if (response.status < 200 || response.status >= 300) {
    throw new Error(
      `Catalog locations API failed (${response.status}): ${response.text.slice(0, 300)}`,
    );
  }
  return response.text;
}

export function findEntityByName(
  entities: AiModelServerApiEntity[],
  nameSubstring: string,
): AiModelServerApiEntity | undefined {
  return entities.find((entity) =>
    entity.metadata.name.toLowerCase().includes(nameSubstring.toLowerCase()),
  );
}

export function kserveManagedEntities(
  entities: AiModelServerApiEntity[],
): AiModelServerApiEntity[] {
  return entities.filter((entity) =>
    (
      entity.metadata.annotations?.["backstage.io/managed-by-location"] ?? ""
    ).includes("ModelCatalogResourceEntityProvider"),
  );
}

export function entityPagePath(entity: AiModelServerApiEntity): string {
  const namespace = entity.metadata.namespace || "default";
  return `/catalog/${namespace}/aimodelserverapi/${entity.metadata.name}`;
}

export function skipIngestionIfNoEntities(
  entities: AiModelServerApiEntity[],
): void {
  if (entities.length > 0) {
    return;
  }
  if (isKserveE2eRequired()) {
    throw new Error(
      "KSERVE_E2E=true but no kserve-managed AiModelServerAPI entities were found. " +
        "Apply tests/fixtures/kserve (see docs/TESTING.md) and wait for status.url.",
    );
  }
  test.skip(
    true,
    "No kserve-managed AiModelServerAPI entities ingested. Apply tests/fixtures/kserve and set KSERVE_E2E=true to fail when missing.",
  );
}

export function expectOverrideSpec(entity: AiModelServerApiEntity): void {
  expect(entity.spec.system, "spec.system override").toBe(OVERRIDE_SYSTEM);
  expect(entity.spec.serverType, "spec.serverType override").toBe(
    OVERRIDE_SERVER_TYPE,
  );
  expect(entity.spec.lifecycle, "spec.lifecycle override").toBe(
    OVERRIDE_LIFECYCLE,
  );
  expect(entity.spec.owner ?? "", "spec.owner override").toContain(
    OVERRIDE_OWNER_SUBSTRING,
  );
  expect(entity.spec.models?.default, "spec.models.default override").toBe(
    OVERRIDE_DEFAULT_MODEL,
  );
  expect(
    entity.spec.models?.available ?? [],
    "spec.models.available override",
  ).toEqual(expect.arrayContaining([...OVERRIDE_AVAILABLE_MODELS]));
}

export function expectTechDocsRefForFixture(
  entity: AiModelServerApiEntity,
): void {
  const techdocsRef =
    entity.metadata.annotations?.["backstage.io/techdocs-ref"];
  expect(
    techdocsRef,
    "catalog-source/catalog-model should set backstage.io/techdocs-ref",
  ).toBeTruthy();
  expect(techdocsRef).toContain("/modelcard/");
  expect(techdocsRef).toContain(FIXTURE_CATALOG_SOURCE);
  expect(techdocsRef).toContain(FIXTURE_CATALOG_MODEL);
}
