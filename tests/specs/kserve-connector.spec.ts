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
  attachIdentityTokenCapture,
  expectOverrideSpec,
  expectTechDocsRefForFixture,
  fetchAiModelServerEntities,
  fetchCatalogLocationsBody,
  fetchConnectorDiscovery,
  findEntityByName,
  getBackstageIdentityToken,
  isKserveE2eRequired,
  kserveManagedEntities,
  type AiModelServerApiEntity,
} from "../support/kserve-connector";

test.describe.skip("KServe / KubeFlow connector", () => {
  test.describe.configure({ timeout: 7 * 60 * 1000 });

  let context: BrowserContext;
  let page: Page;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(10 * 60 * 1000);
    ({ context, page } = await createAuthenticatedSession(browser, {
      onPage: attachIdentityTokenCapture,
    }));
    await expect(page.getByRole("combobox", { name: "Search..." })).toBeVisible({
      timeout: 60_000,
    });
    await expect
      .poll(async () => (await getBackstageIdentityToken(page)) ?? "", {
        timeout: 30_000,
        message: "Backstage identity token was not available after login",
      })
      .not.toEqual("");
  });

  test.afterAll(async () => {
    await context?.close();
  });

  // Always runs on Kind CI — no InferenceServices required.
  test.describe("install checks", () => {
    test("in-process connector plugin is loaded", async () => {
      const discovery = await fetchConnectorDiscovery(page);
      expect(
        discovery.status,
        `GET /api/kserve-kubeflow-connector/list failed: ${discovery.status}`,
      ).toBe(200);
      expect(Array.isArray(discovery.uris)).toBe(true);
    });

    test("catalog has no leftover sidecar location on localhost:9090", async () => {
      const body = await fetchCatalogLocationsBody(page);
      expect(body).not.toContain(LEGACY_SIDECAR_LOCATION);
      for (const sidecar of LEGACY_SIDECAR_NAMES) {
        expect(body.toLowerCase()).not.toContain(sidecar);
      }
    });
  });

  // Cluster / fixture coverage — skipped unless KSERVE_E2E=true.
  test.describe("cluster fixtures (KSERVE_E2E)", () => {
    test.skip(
      !isKserveE2eRequired(),
      "Set KSERVE_E2E=true after applying tests/fixtures/kserve (see docs/TESTING.md)",
    );

    test.describe.configure({ mode: "serial" });

    let entities: AiModelServerApiEntity[] = [];

    test.beforeAll(async () => {
      entities = kserveManagedEntities(await fetchAiModelServerEntities(page));
      if (entities.length === 0) {
        throw new Error(
          "KSERVE_E2E=true but no kserve-managed AiModelServerAPI entities were found. " +
            "Apply tests/fixtures/kserve and wait for status.url.",
        );
      }
    });

    test("connector packages are listed in Extensions", async () => {
      const onExtensions = await openExtensionsInstalledPackages(page);
      expect(
        onExtensions,
        "Extensions page should be available when KSERVE_E2E=true",
      ).toBe(true);
      const table = page.locator("tbody tr, [data-testid='installed-list']");
      await expect(table.first()).toBeVisible({ timeout: 30_000 });

      for (const pkg of CONNECTOR_PACKAGE_SUBSTRINGS) {
        await expect(
          page.getByText(pkg, { exact: false }).first(),
          `Installed packages should include ${pkg}`,
        ).toBeVisible();
      }
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
        expect(
          entity.metadata.annotations?.["backstage.io/managed-by-location"] ??
            "",
        ).toMatch(/ModelCatalogResourceEntityProvider/i);
      }
    });

    test("catalog UI lists and opens a model server entity", async () => {
      const entity = entities[0];
      await openCatalogIndex(page);
      const listed = page.getByText(entity.metadata.name, { exact: false });
      if (
        await listed
          .first()
          .isVisible({ timeout: 15_000 })
          .catch(() => false)
      ) {
        await listed.first().click();
      } else {
        await openEntityPage(page, entity);
      }
      await expect(page).toHaveURL(new RegExp(entity.metadata.name, "i"));
      if (entity.spec.serverType) {
        await expect(
          page.getByText(entity.spec.serverType, { exact: false }).first(),
        ).toBeVisible();
      }
    });

    test("annotation overrides populate system, serverType, models, and default", async () => {
      const override = findEntityByName(
        entities,
        OVERRIDE_ENTITY_NAME_SUBSTRING,
      );
      expect(
        override,
        `Apply inferenceservice-overrides.yaml (entity name contains '${OVERRIDE_ENTITY_NAME_SUBSTRING}')`,
      ).toBeTruthy();

      expectOverrideSpec(override!);

      await openEntityPage(page, override!);
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
      expect(
        fixtureEntity,
        "Apply tests/fixtures/kserve InferenceServices with rhdh.io/catalog-source and rhdh.io/catalog-model",
      ).toBeTruthy();

      expectTechDocsRefForFixture(fixtureEntity!);

      await openEntityPage(page, fixtureEntity!);
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
