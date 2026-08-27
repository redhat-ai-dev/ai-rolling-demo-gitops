import { expect, test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import {
  entityDocsTab,
  openCatalogIndex,
  openEntityPage,
  openExtensionsInstalledPackages,
} from "../support/catalog-page";
import {
  CONNECTOR_PACKAGE_SUBSTRINGS,
  LEGACY_SIDECAR_LOCATION,
  LEGACY_SIDECAR_NAMES,
  OVERRIDE_ENTITY_NAME_SUBSTRING,
  OVERRIDE_SERVER_TYPE,
  OVERRIDE_SYSTEM,
  expectOverrideSpec,
  expectTechDocsRefForFixture,
  fetchAiModelServerEntities,
  fetchCatalogLocationsBody,
  fetchConnectorDiscovery,
  findEntityByName,
  isKserveE2eRequired,
  skipIngestionIfNoEntities,
  type AiModelServerApiEntity,
} from "../support/kserve-connector";

test.describe("KServe / KubeFlow connector", () => {
  test.describe.configure({ timeout: 7 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;
  let entities: AiModelServerApiEntity[] = [];

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(10 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser));
  });

  test.afterAll(async () => {
    await context?.close();
  });

  test("in-process connector plugin is loaded", async () => {
    const discovery = await fetchConnectorDiscovery(page);
    expect(
      discovery.status,
      "GET /api/kserve-kubeflow-connector/list should succeed when the standalone plugin is installed (no sidecar)",
    ).toBe(200);
    expect(Array.isArray(discovery.uris)).toBe(true);
  });

  test("catalog has no leftover sidecar location on localhost:9090", async () => {
    let body: string;
    try {
      body = await fetchCatalogLocationsBody(page);
    } catch (error) {
      if (isKserveE2eRequired()) {
        throw error;
      }
      test.skip(
        true,
        `Catalog locations API unavailable: ${String(error)}`,
      );
      return;
    }
    expect(body).not.toContain(LEGACY_SIDECAR_LOCATION);
    for (const sidecar of LEGACY_SIDECAR_NAMES) {
      expect(body.toLowerCase()).not.toContain(sidecar);
    }
  });

  test("connector packages are listed in Extensions", async () => {
    await openExtensionsInstalledPackages(page);
    const table = page.locator("tbody tr, [data-testid='installed-list']");
    const tableVisible = await table
      .first()
      .isVisible({ timeout: 60_000 })
      .catch(() => false);
    if (!tableVisible) {
      test.skip(true, "Extensions installed-packages table was not rendered");
      return;
    }

    for (const pkg of CONNECTOR_PACKAGE_SUBSTRINGS) {
      await expect(
        page.getByText(pkg, { exact: false }).first(),
        `Installed packages should include ${pkg}`,
      ).toBeVisible();
    }
  });

  test.describe("entity provider ingestion", () => {
    test.describe.configure({ mode: "serial" });

    test.beforeAll(async () => {
      try {
        entities = await fetchAiModelServerEntities(page);
      } catch (error) {
        if (isKserveE2eRequired()) {
          throw error;
        }
        test.skip(true, `Catalog API unavailable: ${String(error)}`);
        return;
      }
      skipIngestionIfNoEntities(entities);
    });

    test("ingests InferenceServices as AiModelServerAPI entities", async () => {
      expect(entities.length).toBeGreaterThan(0);

      for (const entity of entities) {
        expect(entity.kind).toMatch(/AiModelServerAPI/i);
        expect(entity.spec.type).toBe("ai-model-server");
        expect(entity.spec.serverType, "spec.serverType").toBeTruthy();
        expect(
          entity.spec.serverUrl,
          "spec.serverUrl from InferenceService status",
        ).toBeTruthy();
        expect(
          entity.spec.models?.available?.length ?? 0,
          "spec.models.available",
        ).toBeGreaterThan(0);

        const managedBy =
          entity.metadata.annotations?.["backstage.io/managed-by-location"] ??
          "";
        expect(managedBy).toMatch(/ModelCatalogResourceEntityProvider/i);
        expect(managedBy.toLowerCase()).not.toContain(LEGACY_SIDECAR_LOCATION);
      }
    });

    test("catalog UI lists and opens a model server entity", async () => {
      const entity = entities[0];
      await openCatalogIndex(page);
      const listed = page.getByText(entity.metadata.name, { exact: false });
      if (await listed.first().isVisible({ timeout: 30_000 }).catch(() => false)) {
        await listed.first().click();
      } else {
        await openEntityPage(page, entity);
      }
      await expect(page).toHaveURL(new RegExp(entity.metadata.name, "i"));
      await expect(
        page.getByText(entity.spec.serverType ?? "", { exact: false }).first(),
      ).toBeVisible();
    });

    test("annotation overrides populate system, serverType, models, and default", async () => {
      const override = findEntityByName(
        entities,
        OVERRIDE_ENTITY_NAME_SUBSTRING,
      );
      if (!override) {
        test.skip(
          true,
          `Apply inferenceservice-overrides.yaml (entity name contains '${OVERRIDE_ENTITY_NAME_SUBSTRING}')`,
        );
        return;
      }

      expectOverrideSpec(override);

      await openEntityPage(page, override);
      await expect(
        page.getByText(OVERRIDE_SYSTEM, { exact: false }),
      ).toBeVisible();
      await expect(
        page.getByText(OVERRIDE_SERVER_TYPE, { exact: false }),
      ).toBeVisible();
      await expect(
        page.getByText("sklearn-iris-primary", { exact: false }).first(),
      ).toBeVisible();
    });

    test("catalog-source and catalog-model annotations import TechDocs", async () => {
      const fixtureEntity =
        findEntityByName(entities, OVERRIDE_ENTITY_NAME_SUBSTRING) ??
        findEntityByName(entities, "sklearn-iris");
      if (!fixtureEntity) {
        test.skip(
          true,
          "Apply tests/fixtures/kserve InferenceServices with rhdh.io/catalog-source and rhdh.io/catalog-model",
        );
        return;
      }

      expectTechDocsRefForFixture(fixtureEntity);

      await openEntityPage(page, fixtureEntity);
      const docsTab = entityDocsTab(page);
      if (
        await docsTab
          .first()
          .isVisible({ timeout: 15_000 })
          .catch(() => false)
      ) {
        await docsTab.first().click();
        await expect(
          page.getByText(/techdocs|model card|documentation/i).first(),
        ).toBeVisible({ timeout: 60_000 });
      }
    });
  });
});
