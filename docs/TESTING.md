# Testing

The `tests/` directory contains an E2E test suite for the AI Rolling Demo UI. Those tests are also used by our nightly CI run (`.github/workflows/nightly.yml`) and by our CI PR check (`.github/workflows/ci-pr-check.yaml`).

## Running CI tests locally

A user is also able to run our testing suite locally (`make ci-install && make ci-tests`). This will spin up a local [Kind](https://kind.sigs.k8s.io/) cluster, deploy RHDH via Helm, and then run the same E2E suite. This way local changes can be tested before pushed on the github repo.

### Prerequisites

- `kind` v0.23.0+
- `helm` v3+
- `kubectl`
- `openssl`
- `python` version greater than `3.11`.
- [uv](https://docs.astral.sh/uv/) installed (`pip install uv` or via the official installer).
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

# Optional: The argoCD creds are not required for our
# current testing suite, so you can export dummy values
# here too OR leave them empty and they will get assigned with
# random values automatically
export ARGOCD_USER="<user>"
export ARGOCD_PASSWORD="<password>"
export ARGOCD_HOSTNAME="<argocd-host>"
export ARGOCD_API_TOKEN="<api-token>"

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

## Troubleshooting

- **Test suite fails on first `test_navbar.py` test**: If Kind cluster is created successfully but then your tests are failing when an authenticated session is required (e.g. `test_navbar` which is the first group of tests ran where auth is required), you have most probably haven't exported correctly the variables mentioned in [Prepare `scripts/private-env`](#prepare-scriptsprivate-env).

- **Tests hit wrong RHDH URL (e.g. your OCP cluster's hostname instead of `rhdh-ci.apps.testing`)**: This usually means `RHDH_BASE_URL` was set to a custom value before running `make ci-tests`. The CI scripts derive `RHDH_BASE_URL` from `CI_HOSTNAME` (default: `rhdh-ci.apps.testing`). Do not set `RHDH_BASE_URL` manually when running local CI tests — unset it and let `run-tests.sh` compute it. Note that `RHDH_CLUSTER_ROUTER_BASE` (used for OCP deployments) does **not** affect the local Kind CI hostname; `clusterRouterBase` is fixed to `apps.testing` in `ci/values-ci.yaml`.
