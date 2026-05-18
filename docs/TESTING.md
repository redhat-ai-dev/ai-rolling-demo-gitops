# Testing

The `tests/` directory contains an E2E test suite for the AI Rolling Demo UI. Those tests are also used by our nightly CI run (`.github/workflows/nightly.yml`) which verifies that the deployed RHDH instances work and behave as expected.

## Prerequisites

- `python` version greater than `3.11`.
- [uv](https://docs.astral.sh/uv/) installed (`pip install uv` or via the official installer).
- A running RHDH instance (e.g. deployed via `make install`).

## Set up the test environment

```bash
cd tests
uv sync
uv run playwright install chromium
```

## Running tests locally

Assuming you have followed the [SETUP_GUIDE](SETUP_GUIDE.md), you should have already set the following variables in your `private-env`:

- `ARGOCD_APP_NAME`
- `RHDH_NAMESPACE`
- `RHDH_CLUSTER_ROUTER_BASE`
- `KEYCLOAK_CLIENT_ID`
- `KEYCLOAK_CLIENT_SECRET`

Add the required variables to `scripts/private-env`:

```bash
# RHDH_BASE_URL is your RHDH instance base url. It is derived from ARGOCD_APP_NAME, RHDH_NAMESPACE, and RHDH_CLUSTER_ROUTER_BASE.
export RHDH_BASE_URL="https://${ARGOCD_APP_NAME}-backstage-${RHDH_NAMESPACE}.${RHDH_CLUSTER_ROUTER_BASE}"
# Default is production unless otherwise set in app-config
export RHDH_ENVIRONMENT="production"
# Your (or a test user's) keycloak username. This user has to be present both in keycloak but also in RHDH.
# If you have followed the SETUP_GUIDE your keycloak's users should have already been imported in your RHDH instance.
# for example, if your keycloak ID is 'myid@redhat.com', you want to set this env var to 'myid'
export ROLLING_DEMO_TEST_USERNAME="keycloak-demo-user"
# Optional: set to "false" to run tests with a visible browser window (default: "true")
export PLAYWRIGHT_HEADLESS="false"
```

Then run:

```bash
make tests
```

**NOTE**: It will exit with an error if `tests/.venv` does not exist or if `uv`/`pytest` is not available after activating the `.venv`.

## Running CI tests locally

The CI pipeline (`make ci-install && make ci-tests`) spins up a local [Kind](https://kind.sigs.k8s.io/) cluster, deploys RHDH via Helm, and then runs the same E2E suite. You can reproduce this locally before pushing.

### Additional prerequisites

- `kind` v0.23.0+
- `helm` v3+
- `kubectl`
- `openssl`
- `sudo` access (the script writes to `/etc/hosts`)

### Create `scripts/private-env`

`ci-setup.sh` automatically sources `scripts/private-env` when it exists. The file is gitignored (`*private-env`). Create it with the variables below — all are required unless marked optional.

```bash
# Keycloak / OIDC
export KEYCLOAK_METADATA_URL="https://<host>/realms/<realm>/.well-known/openid-configuration"
export KEYCLOAK_BASE_URL="https://<host>"
export KEYCLOAK_REALM="<realm>"
export KEYCLOAK_LOGIN_REALM="<login-realm>"       # often "master"
export KEYCLOAK_CLIENT_ID="<client-id>"
export KEYCLOAK_CLIENT_SECRET="<client-secret>"

# Quay pull secret — raw JSON from ~/.docker/config.json or a robot account token
export QUAY_DOCKERCONFIGJSON='{"auths":{"quay.io":{"auth":"<base64>"}}}'

# vLLM / Lightspeed inference backend
export VLLM_URL="https://<vllm-host>"
export VLLM_API_KEY="<api-key>"
export VALIDATION_PROVIDER="<provider>"           # e.g. "openai"
export VALIDATION_MODEL_NAME="<model>"

# Lightspeed PostgreSQL
export LIGHTSPEED_POSTGRES_USER="<user>"
export LIGHTSPEED_POSTGRES_PASSWORD="<password>"
export LIGHTSPEED_POSTGRES_DB="<db-name>"

# Notebooks
export NOTEBOOKS_QUERY_PROVIDER_ID="<provider-id>"
export NOTEBOOKS_QUERY_MODEL="<model>"

# ArgoCD
export ARGOCD_USER="<user>"                       # e.g. "admin"
export ARGOCD_PASSWORD="<password>"
export ARGOCD_HOSTNAME="<argocd-host>"
export ARGOCD_API_TOKEN="<api-token>"

# E2E test identity
export ROLLING_DEMO_TEST_USERNAME="<keycloak-username>"
export RHDH_ENVIRONMENT="ci"
```

### Run

```bash
make ci-install   # creates Kind cluster and deploys RHDH (~20 min)
make ci-tests     # runs the Playwright E2E suite
```

To tear down the cluster afterwards:

```bash
kind delete cluster --name rhdh-ci
```

## GitHub repository secrets

The CI PR check workflow (`.github/workflows/ci-pr-check.yaml`) reads the same variables from GitHub Actions secrets. Add the following secrets in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `KEYCLOAK_METADATA_URL` | OIDC discovery URL |
| `KEYCLOAK_BASE_URL` | Keycloak base URL |
| `KEYCLOAK_REALM` | Realm name |
| `KEYCLOAK_LOGIN_REALM` | Login realm (often `master`) |
| `KEYCLOAK_CLIENT_ID` | OIDC client ID |
| `KEYCLOAK_CLIENT_SECRET` | OIDC client secret |
| `QUAY_DOCKERCONFIGJSON` | Quay pull secret (raw JSON) |
| `VLLM_URL` | vLLM endpoint URL |
| `VLLM_API_KEY` | vLLM API key |
| `VALIDATION_PROVIDER` | Validation provider name |
| `VALIDATION_MODEL_NAME` | Validation model name |
| `LIGHTSPEED_POSTGRES_USER` | Lightspeed DB username |
| `LIGHTSPEED_POSTGRES_PASSWORD` | Lightspeed DB password |
| `LIGHTSPEED_POSTGRES_DB` | Lightspeed DB name |
| `NOTEBOOKS_QUERY_PROVIDER_ID` | Notebooks query provider ID |
| `NOTEBOOKS_QUERY_MODEL` | Notebooks query model |
| `ARGOCD_USER` | ArgoCD username |
| `ARGOCD_PASSWORD` | ArgoCD password |
| `ARGOCD_HOSTNAME` | ArgoCD hostname |
| `ARGOCD_API_TOKEN` | ArgoCD API token |
| `ROLLING_DEMO_TEST_USERNAME` | Keycloak username used by E2E tests |
| `RHDH_ENVIRONMENT` | Environment label passed to tests (e.g. `ci`) |
