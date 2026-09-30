import type { Page } from "@playwright/test";
import {
  attachIdentityTokenCapture,
  authenticatedGet,
  getBackstageIdentityToken,
  type AiModelServerApiEntity,
} from "./kserve-connector";

export {
  attachIdentityTokenCapture,
  getBackstageIdentityToken,
  type AiModelServerApiEntity,
};

export const OGX_PACKAGE_SUBSTRINGS = [
  "ogx-entity-provider",
  "ai-catalog",
  "catalog-backend-module-ai-resource-agent",
  "catalog-backend-module-ai-model-server",
] as const;

/** Config-driven agent entity names emitted by OgxAgentEntityProvider. */
export const EXPECTED_AGENT_ENTITY_NAMES = [
  "ogx-agent-router",
  "ogx-agent-legal",
  "ogx-agent-support",
  "ogx-agent-hr",
  "ogx-agent-sales",
  "ogx-agent-procurement",
] as const;

export const OGX_MODEL_PROVIDER_ID = "ogx-model-entity-provider";
export const OGX_AGENT_PROVIDER_ID = "ogx-agent-entity-provider";
export const OGX_MODEL_SERVER_ENTITY_NAME = "ogx-model-server";

export type AiResourceEntity = {
  apiVersion: string;
  kind: string;
  metadata: {
    name: string;
    namespace?: string;
    title?: string;
    description?: string;
    annotations?: Record<string, string>;
  };
  spec: {
    type?: string;
    lifecycle?: string;
    owner?: string;
    model?: string;
    instructions?: string;
    handoffs?: string[];
    enableRAG?: boolean;
  };
};

type CatalogByQueryResponse<T> = {
  items?: Array<{ entity?: T }>;
};

function parseJson<T>(text: string): T | undefined {
  try {
    return JSON.parse(text) as T;
  } catch {
    return undefined;
  }
}

export function isOgxE2eRequired(): boolean {
  return (process.env.OGX_E2E ?? "").toLowerCase() === "true";
}

export async function fetchAiResourceEntities(
  page: Page,
): Promise<AiResourceEntity[]> {
  const byQuery = await authenticatedGet(
    page,
    "/api/catalog/entities/by-query",
    { filter: "kind=airesource", limit: "200" },
  );
  if (byQuery.status >= 200 && byQuery.status < 300) {
    const body = parseJson<CatalogByQueryResponse<AiResourceEntity>>(
      byQuery.text,
    );
    if (Array.isArray(body?.items)) {
      return body.items
        .map((item) => item.entity)
        .filter((entity): entity is AiResourceEntity => Boolean(entity));
    }
  }

  const legacy = await authenticatedGet(page, "/api/catalog/entities", {
    filter: "kind=AiResource",
  });
  if (legacy.status < 200 || legacy.status >= 300) {
    throw new Error(
      `Catalog API failed (${legacy.status}): ${legacy.text.slice(0, 300)}`,
    );
  }
  const entities = parseJson<AiResourceEntity[]>(legacy.text);
  return Array.isArray(entities) ? entities : [];
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
    const body = parseJson<CatalogByQueryResponse<AiModelServerApiEntity>>(
      byQuery.text,
    );
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

export function ogxManagedAgents(
  entities: AiResourceEntity[],
): AiResourceEntity[] {
  return entities.filter((entity) => {
    const location =
      entity.metadata.annotations?.["backstage.io/managed-by-location"] ??
      entity.metadata.annotations?.["backstage.io/location"] ??
      "";
    return (
      location.includes(OGX_AGENT_PROVIDER_ID) ||
      (entity.spec.type === "agent" &&
        entity.metadata.name.startsWith("ogx-agent-"))
    );
  });
}

export function ogxManagedModelServers(
  entities: AiModelServerApiEntity[],
): AiModelServerApiEntity[] {
  return entities.filter((entity) => {
    const location =
      entity.metadata.annotations?.["backstage.io/managed-by-location"] ??
      entity.metadata.annotations?.["backstage.io/location"] ??
      "";
    return (
      location.includes(OGX_MODEL_PROVIDER_ID) ||
      entity.metadata.name === OGX_MODEL_SERVER_ENTITY_NAME
    );
  });
}

export function airesourcePagePath(entity: AiResourceEntity): string {
  const namespace = entity.metadata.namespace || "default";
  return `/catalog/${namespace}/airesource/${entity.metadata.name}`;
}
