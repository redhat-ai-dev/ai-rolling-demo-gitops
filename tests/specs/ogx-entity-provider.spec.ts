import { expect, test } from "@playwright/test";
import type { BrowserContext, Page } from "@playwright/test";
import { createAuthenticatedSession } from "../support/browser-context";
import {
  openCatalogIndex,
  openExtensionsInstalledPackages,
} from "../support/catalog-page";
import {
  EXPECTED_AGENT_ENTITY_NAMES,
  OGX_MODEL_SERVER_ENTITY_NAME,
  OGX_PACKAGE_SUBSTRINGS,
  airesourcePagePath,
  attachIdentityTokenCapture,
  fetchAiModelServerEntities,
  fetchAiResourceEntities,
  getBackstageIdentityToken,
  isOgxE2eRequired,
  ogxManagedAgents,
  ogxManagedModelServers,
  type AiResourceEntity,
} from "../support/ogx-entity-provider";

test.describe("OGX entity provider", () => {
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

  // Always runs on Kind CI — agents come from app-config, no live OGX required.
  // Run catalog assertions before optional Extensions UI (Kind often has an empty
  // installed-packages table; package presence is covered by Helm CI).
  test.describe("install checks", () => {
    test("ingests config agents as AiResource (type agent)", async () => {
      let agents: AiResourceEntity[] = [];
      await expect
        .poll(
          async () => {
            agents = ogxManagedAgents(await fetchAiResourceEntities(page));
            return agents.length;
          },
          {
            timeout: 3 * 60 * 1000,
            message:
              "Expected ogx-agent-* AiResource entities from ai-catalog.entityProviders.ogx. " +
              "If empty, values.yaml may still be under legacy boost.entityProviders.ogx.",
          },
        )
        .toBeGreaterThan(0);

      const names = new Set(agents.map((entity) => entity.metadata.name));
      for (const expected of EXPECTED_AGENT_ENTITY_NAMES) {
        expect(names.has(expected), `missing agent entity ${expected}`).toBe(
          true,
        );
      }

      for (const agent of agents) {
        expect(agent.kind).toMatch(/AiResource/i);
        expect(agent.spec.type).toBe("agent");
        expect(agent.spec.instructions, "spec.instructions").toBeTruthy();
      }
    });

    test("catalog UI lists and opens a config agent entity", async () => {
      const agents = ogxManagedAgents(await fetchAiResourceEntities(page));
      const router =
        agents.find((entity) => entity.metadata.name === "ogx-agent-router") ??
        agents[0];
      expect(router, "at least one OGX agent entity").toBeTruthy();

      await openCatalogIndex(page);
      const listed = page.getByText(router.metadata.name, { exact: false });
      if (
        await listed
          .first()
          .isVisible({ timeout: 15_000 })
          .catch(() => false)
      ) {
        await listed.first().click();
      } else {
        await page.goto(airesourcePagePath(router), {
          waitUntil: "domcontentloaded",
        });
      }
      await expect(page).toHaveURL(new RegExp(router.metadata.name, "i"));
      await expect(
        page.getByText(/FantaCo Router|agent/i).first(),
      ).toBeVisible({ timeout: 30_000 });
    });

    // Optional per RHIDP-17280 — same UI gate as KServe (only useful when the
    // Extensions installed-packages table is populated).
    test("OGX / AI Catalog packages are listed in Extensions", async () => {
      const onExtensions = await openExtensionsInstalledPackages(page);
      test.skip(
        !onExtensions,
        "Extensions page unavailable in this deployment",
      );

      const table = page.locator("tbody tr");
      const hasRows = await table
        .first()
        .isVisible({ timeout: 15_000 })
        .catch(() => false);
      test.skip(
        !hasRows,
        "Extensions installed-packages table empty (Kind CI); packages asserted by Helm",
      );

      for (const pkg of OGX_PACKAGE_SUBSTRINGS) {
        await expect(
          page.getByText(pkg, { exact: false }).first(),
          `Installed packages should include ${pkg}`,
        ).toBeVisible();
      }
    });
  });

  // Live OGX /v1/models — skipped unless OGX_E2E=true (RHOAI 3.x+ / team OGX).
  test.describe("cluster OGX models (OGX_E2E)", () => {
    test.skip(
      !isOgxE2eRequired(),
      "Set OGX_E2E=true with BOOST_OGX_URL pointing at a live OGX (see docs/TESTING.md)",
    );

    test.describe.configure({ mode: "serial" });

    test("ingests OGX /v1/models as AiModelServerAPI", async () => {
      let servers = ogxManagedModelServers(
        await fetchAiModelServerEntities(page),
      );
      await expect
        .poll(
          async () => {
            servers = ogxManagedModelServers(
              await fetchAiModelServerEntities(page),
            );
            return servers.length;
          },
          {
            timeout: 3 * 60 * 1000,
            message:
              "OGX_E2E=true but no ogx-model-server AiModelServerAPI was found. " +
              "Confirm BOOST_OGX_URL reaches /v1/models.",
          },
        )
        .toBeGreaterThan(0);

      const server =
        servers.find(
          (entity) => entity.metadata.name === OGX_MODEL_SERVER_ENTITY_NAME,
        ) ?? servers[0];

      expect(server.kind).toMatch(/AiModelServerAPI/i);
      expect(server.spec.type).toBe("ai-model-server");
      expect(server.spec.serverType).toBe("openai-v1");
      expect(server.spec.serverUrl, "spec.serverUrl").toBeTruthy();
      expect(
        server.spec.models?.available?.length ?? 0,
        "spec.models.available from OGX /v1/models",
      ).toBeGreaterThan(0);
    });
  });
});
