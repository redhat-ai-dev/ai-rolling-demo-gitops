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

export function isKserveE2eRequired(): boolean {
  return (process.env.KSERVE_E2E ?? "").toLowerCase() === "true";
}

export async function fetchConnectorDiscovery(
  page: Page,
): Promise<{ status: number; uris: string[] }> {
  const response = await page.request.get(KSERVE_CONNECTOR_LIST_PATH);
  if (!response.ok()) {
    return { status: response.status(), uris: [] };
  }
  const body = (await response.json()) as { uris?: string[] };
  return { status: response.status(), uris: body.uris ?? [] };
}

export async function fetchAiModelServerEntities(
  page: Page,
): Promise<AiModelServerApiEntity[]> {
  const byQuery = await page.request.get("/api/catalog/entities/by-query", {
    params: { filter: "kind=aimodelserverapi", limit: "100" },
  });
  if (byQuery.ok()) {
    const body = (await byQuery.json()) as CatalogByQueryResponse;
    if (Array.isArray(body.items)) {
      return body.items
        .map((item) => item.entity)
        .filter((entity): entity is AiModelServerApiEntity => Boolean(entity));
    }
  }

  const legacy = await page.request.get("/api/catalog/entities", {
    params: { filter: "kind=AiModelServerAPI" },
  });
  if (!legacy.ok()) {
    throw new Error(
      `Catalog API failed (${legacy.status()}): ${await legacy.text()}`,
    );
  }
  const entities = (await legacy.json()) as AiModelServerApiEntity[];
  return Array.isArray(entities) ? entities : [];
}

export async function fetchCatalogLocationsBody(page: Page): Promise<string> {
  const response = await page.request.get("/api/catalog/locations");
  if (!response.ok()) {
    throw new Error(
      `Catalog locations API failed (${response.status()}): ${await response.text()}`,
    );
  }
  return response.text();
}

export function findEntityByName(
  entities: AiModelServerApiEntity[],
  nameSubstring: string,
): AiModelServerApiEntity | undefined {
  return entities.find((entity) =>
    entity.metadata.name.toLowerCase().includes(nameSubstring.toLowerCase()),
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
      "KSERVE_E2E=true but no AiModelServerAPI entities were found. " +
        "Apply tests/fixtures/kserve (see docs/TESTING.md) and wait for status.url.",
    );
  }
  test.skip(
    true,
    "No AiModelServerAPI entities ingested. Apply tests/fixtures/kserve and set KSERVE_E2E=true to fail when missing.",
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
  const techdocsRef = entity.metadata.annotations?.["backstage.io/techdocs-ref"];
  expect(
    techdocsRef,
    "catalog-source/catalog-model should set backstage.io/techdocs-ref",
  ).toBeTruthy();
  expect(techdocsRef).toContain("/modelcard/");
  expect(techdocsRef).toContain(FIXTURE_CATALOG_SOURCE);
  expect(techdocsRef).toContain(FIXTURE_CATALOG_MODEL);
}
