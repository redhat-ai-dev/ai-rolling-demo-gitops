# Testing

The `tests/` directory contains an E2E test suite for the AI Rolling Demo UI. Those tests are also used by our nightly CI run (`.github/workflows/nightly.yml`) and by our CI PR check (`.github/workflows/ci-pr-check.yaml`).

## Running CI tests locally

A user is also able to run our testing suite locally (`make ci-install && make ci-tests`). This will spin up a local [Kind](https://kind.sigs.k8s.io/) cluster, deploy RHDH via Helm, and then run the same E2E suite. This way local changes can be tested before pushed on the github repo.

### Prerequisites

- `kind` v0.23.0+
- `helm` v3+
- `kubectl`
- `openssl`
- `node` version greater than or equal to `24`.
- `npm` (bundled with Node).
- `sudo` access (the script writes to `/etc/hosts`)

### Prepare `scripts/private-env`

`ci-setup.sh` automatically sources `scripts/private-env`. Make sure your file has the following environment variables exported. For more details check the [docs/SETUP_GUIDE.md#setup-the-private-env-file](./SETUP_GUIDE.md#setup-the-private-env-file) section.

```bash
# Keycloak / OIDC
export KEYCLOAK_METADATA_URL="https://<host>/realms/<realm>/.well-known/openid-configuration"
export KEYCLOAK_BASE_URL="https://<host>"
export KEYCLOAK_REALM="<realm>"
export KEYCLOAK_LOGIN_REALM="<login-realm>"
export KEYCLOAK_CLIENT_ID="<client-id>"
export KEYCLOAK_CLIENT_SECRET="<client-secret>"

# Optional: If you don't have QUAY_DOCKERCONFIGJSON already exported in your private-env
# you can just export a dummy value like the one below
export QUAY_DOCKERCONFIGJSON='{"auths":{"quay.io":{"auth":""}}}'

# Lightspeed inference backend
export VLLM_URL="https://<vllm-host>"
export VLLM_API_KEY="<api-key>"
export VALIDATION_PROVIDER="<provider>"
export VALIDATION_MODEL_NAME="<model>"

# Notebooks
export NOTEBOOKS_QUERY_PROVIDER_ID="<provider-id>"
export NOTEBOOKS_QUERY_MODEL="<model>"

# Boost / OGX (AI Catalog agent chat)
export BOOST_OGX_URL="<ogx-url>"
export BOOST_MODEL="<model-name>"

# Lightspeed PostgreSQL
export LIGHTSPEED_POSTGRES_USER="<user>"
export LIGHTSPEED_POSTGRES_PASSWORD="<password>"
export LIGHTSPEED_POSTGRES_DB="<db-name>"

# GitHub App integration
export GITHUB_APP_APP_ID="<app-id>"
export GITHUB_APP_CLIENT_ID="<client-id>"
export GITHUB_APP_CLIENT_SECRET="<client-secret>"
export GITHUB_APP_WEBHOOK_URL="https://<webhook-host>"
export GITHUB_APP_WEBHOOK_SECRET="<webhook-secret>"
export GITHUB_APP_PRIVATE_KEY="<pem-key>"
export GITOPS_GIT_ORG="<github-org>"

# ArgoCD credentials
# For Kind cluster testing, set real values from "ArgoCD Devcluster Test User Creds" in the team Bitwarden.
# To run against the actual devcluster, these can be left empty.
export ARGOCD_APP_NAME="rolling-demo"
export ARGOCD_USER="<user>"         # see "ArgoCD Devcluster Test User Creds" on team Bitwarden
export ARGOCD_PASSWORD="<password>" # see "ArgoCD Devcluster Test User Creds" on team Bitwarden
export ARGOCD_HOSTNAME="<hostname>" # see "ArgoCD Devcluster Test User Creds" on team Bitwarden
export ARGOCD_API_TOKEN="<token>"   # see "ArgoCD Devcluster Test User Creds" on team Bitwarden

# E2E test identity: ROLLING_DEMO_TEST_USERNAME is an important
# value. You can use your own keycloak username as a test user.
# The script will just impersonate your user while testing your
# local changes on a Kind cluster.
export ROLLING_DEMO_TEST_USERNAME="<keycloak-username>"
export RHDH_ENVIRONMENT="production"
```

**Note**: The `RHDH_CLUSTER_ROUTER_BASE` is overriden automatically by `ci-setup.sh` in testing mode, so the `scripts/private-env` value is ignored. The value used for testing is `apps.testing`

### Run

```bash
make ci-install   # creates Kind cluster and deploys RHDH (~40 min)
make ci-tests     # runs the Playwright E2E suite
```

If you want to run the Playwright suite against an existing RHDH instance (without Kind):

1. Copy `tests/.env.example` to `tests/.env` and fill in the auth values.
2. Run:

```bash
cd tests
npm ci
npx playwright install chromium --with-deps
npx playwright test          # headless
npx playwright test --ui     # interactive UI mode
npx playwright test --headed # headed browser, no UI runner
```

To tear down the cluster afterwards:

```bash
kind delete cluster --name rhdh-ci
```

## GitHub repository secrets

The CI PR check workflow (`.github/workflows/ci-pr-check.yaml`) reads the same variables from GitHub Actions secrets. Add the following secrets in **Settings → Secrets and variables → Actions**.

> **Note on GitHub App secret names**: GitHub Actions reserves the `GITHUB_*` namespace, so the workflow uses `GH_APP_*` names instead (e.g. `GH_APP_APP_ID` instead of `GITHUB_APP_APP_ID`). `ci-setup.sh` maps both names automatically, so locally you keep using the `GITHUB_APP_*` variables in your `private-env`.

| Secret                         | Description                                   |
| ------------------------------ | --------------------------------------------- |
| `KEYCLOAK_METADATA_URL`        | OIDC discovery URL                            |
| `KEYCLOAK_BASE_URL`            | Keycloak base URL                             |
| `KEYCLOAK_REALM`               | Realm name                                    |
| `KEYCLOAK_LOGIN_REALM`         | Login realm (often `master`)                  |
| `KEYCLOAK_CLIENT_ID`           | OIDC client ID                                |
| `KEYCLOAK_CLIENT_SECRET`       | OIDC client secret                            |
| `QUAY_DOCKERCONFIGJSON`        | Quay pull secret (raw JSON)                   |
| `VLLM_URL`                     | vLLM endpoint URL                             |
| `VLLM_API_KEY`                 | vLLM API key                                  |
| `VALIDATION_PROVIDER`          | Validation provider name                      |
| `VALIDATION_MODEL_NAME`        | Validation model name                         |
| `LIGHTSPEED_POSTGRES_USER`     | Lightspeed DB username                        |
| `LIGHTSPEED_POSTGRES_PASSWORD` | Lightspeed DB password                        |
| `LIGHTSPEED_POSTGRES_DB`       | Lightspeed DB name                            |
| `NOTEBOOKS_QUERY_PROVIDER_ID`  | Notebooks query provider ID                   |
| `NOTEBOOKS_QUERY_MODEL`        | Notebooks query model                         |
| `GH_APP_APP_ID`                | GitHub App ID (maps to `GITHUB_APP_APP_ID`)   |
| `GH_APP_CLIENT_ID`             | GitHub App client ID                          |
| `GH_APP_CLIENT_SECRET`         | GitHub App client secret                      |
| `GH_APP_WEBHOOK_URL`           | GitHub App webhook URL                        |
| `GH_APP_WEBHOOK_SECRET`        | GitHub App webhook secret                     |
| `GH_APP_PRIVATE_KEY`           | GitHub App private key (PEM)                  |
| `GITOPS_GIT_ORG`               | GitHub org for GitOps repos                   |
| `ARGOCD_USER`                  | ArgoCD username                               |
| `ARGOCD_PASSWORD`              | ArgoCD password                               |
| `ARGOCD_HOSTNAME`              | ArgoCD hostname                               |
| `ARGOCD_API_TOKEN`             | ArgoCD API token                              |
| `ROLLING_DEMO_TEST_USERNAME`   | Keycloak username used by E2E tests           |
| `RHDH_ENVIRONMENT`             | Environment label passed to tests (e.g. `ci`) |

## KServe / KubeFlow connector QE

Playwright coverage for the standalone `kserve-kubeflow-connector` plugin lives in `tests/specs/kserve-connector.spec.ts`. It maps to the QE plan for both the RHOAI (devcluster) path and upstream KServe / KubeFlow Model Catalog on kind.

Install-level checks always run (plugin HTTP API, no leftover sidecar location at `localhost:9090`, Extensions packages). Ingestion checks skip unless the catalog contains `AiModelServerAPI` entities. Set `KSERVE_E2E=true` to fail instead of skip when nothing was ingested.

| Ticket scenario | How it is covered |
| --- | --- |
| InferenceService discovery + Model Catalog on RHOAI 3.x+ | Apply RHOAI fixtures, then ingestion tests against `AiModelServerAPI` |
| Upstream KServe on kind (no RHOAI APIs) | Apply kind fixtures; same ingestion tests |
| KubeFlow Model Catalog / ModelCard + TechDocs | `rhdh.io/catalog-source` and `rhdh.io/catalog-model` on the IS; entity `backstage.io/techdocs-ref` |
| No sidecar (`location`, `storage-rest`, `rhoai-normalizer`) | Plugin `/api/kserve-kubeflow-connector/list` plus catalog locations must not mention `localhost:9090` |
| Spec overrides (`system`, `serverType`, models, default) | `inferenceservice-overrides.yaml` + entity spec/UI assertions |
| Credentials only via cluster config (no sidecar env vars) | Plugin cluster fields in `kserve-connector-app-config` / `kubernetes.clusterLocatorMethods` in `charts/rhdh/values.yaml` |

### Fixtures

Manifests and helpers are under `tests/fixtures/kserve/`.

```bash
# RHOAI / OpenShift (MLServer ServingRuntime from registry.redhat.io)
tests/fixtures/kserve/apply.sh rhoai ggmtest

# Upstream KServe on kind (RawDeployment, no RHOAI runtime image)
tests/fixtures/kserve/apply.sh kind ggmtest

# Optional: confirm the predictor serves the sklearn-iris V2 API
tests/fixtures/kserve/test-inference.sh ggmtest
```

The connector only emits an `AiModelServerAPI` entity after the InferenceService has `status.url` (or `status.address.url`). Wait for Ready, then give the entity provider a short reconcile window before running tests.

Replace `rhdh.io/catalog-source` / `rhdh.io/catalog-model` with IDs that exist in the target KubeFlow Model Catalog when validating live ModelCard → TechDocs import. The checked-in values (`kserve-qe` / `sklearn-iris`) still prove the annotation → `backstage.io/techdocs-ref` mapping.

### Kind cluster (upstream KServe / KubeFlow)

1. Create a kind cluster and install [KServe](https://kserve.github.io/website/latest/get_started/) (RawDeployment is enough for these fixtures).
2. Optionally install [KubeFlow Model Catalog](https://www.kubeflow.org/docs/components/model-registry/) if you need ModelCard/TechDocs, not just InferenceService discovery.
3. Point RHDH at that cluster with the same credential mechanism used in production: `kubernetes.clusterLocatorMethods` or the connector's cluster `url` / `serviceAccountToken` / `caData` fields (see `charts/rhdh/templates/kserve-connector-config.yaml`). Do not add sidecar env vars.
4. Apply the kind fixtures and run:

```bash
cd tests
KSERVE_E2E=true npx playwright test specs/kserve-connector.spec.ts
```

### RHOAI devcluster

1. Use the team RHOAI 3.x+ cluster that already backs the rolling demo / development instance.
2. Apply the RHOAI fixtures (`apply.sh rhoai`) in a namespace the connector's ServiceAccount can list (`inferenceservices`, `routes`, `serviceaccounts`).
3. Run the same Playwright file with `KSERVE_E2E=true` against that RHDH `RHDH_BASE_URL`.

Helm Chart vs Operator install without sidecars is validated by the GitOps config on `development` (sidecars job no longer injects `location` / `storage-rest` / `rhoai-normalizer`) plus the in-process plugin API test above.

## Troubleshooting

- **Test suite fails on first authenticated Lightspeed spec**: If Kind cluster is created successfully but tests fail before the first `/lightspeed` assertions, the likely issue is missing or wrong auth variables used by the Keycloak impersonation flow (`RHDH_ENVIRONMENT`, `ROLLING_DEMO_TEST_USERNAME`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`).

- **Tests hit wrong RHDH URL (e.g. your OCP cluster's hostname instead of `rhdh-ci.apps.testing`)**: This usually means `RHDH_BASE_URL` was set to a custom value before running `make ci-tests`. The CI scripts derive `RHDH_BASE_URL` from `CI_HOSTNAME` (default: `rhdh-ci.apps.testing`). Do not set `RHDH_BASE_URL` manually when running local CI tests — unset it and let `run-tests.sh` compute it. Note that `RHDH_CLUSTER_ROUTER_BASE` (used for OCP deployments) does **not** affect the local Kind CI hostname; `clusterRouterBase` is fixed to `apps.testing` in `ci/values-ci.yaml` because `ci-setup.sh` writes `127.0.0.1 rhdh-ci.apps.testing` to `/etc/hosts` and configures the Kind ingress to that same hostname — changing the variable alone without re-running the cluster setup would break the routing.
