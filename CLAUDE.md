# ai-rolling-demo-gitops

GitOps repository that drives the **RHDHPAI Rolling Demo** - a live, continuously-updated deployment of Red Hat Developer Hub (RHDH) on OpenShift, showcasing AI software templates, Lightspeed chat, Model Catalog Bridge, and MCP plugins.

See @CLAUDE-ORG.md for broader organizational context and component relationships.

## Key Commands

```bash
make install                  # Full cluster setup (runs setup.sh)
make install-no-rhoai         # Full setup but skips RHOAI/Model Catalog Bridge provisioning
make tests                    # Run E2E Playwright tests
bash scripts/run-tests.sh     # Run tests directly
shellcheck scripts/*.sh       # Lint shell scripts locally before pushing
```

## Branch Strategy

| Branch        | ArgoCD App        | Namespace            | Purpose                 |
| ------------- | ----------------- | -------------------- | ----------------------- |
| `main`        | `rolling-demo`    | `rolling-demo-ns`    | Production, auto-synced |
| `development` | `rhdhai-rhdh-dev` | `rhdhai-development` | Staging, auto-synced    |

Always target `development` for new changes. Promote to `main` via PR after validation on staging. Automation branches (`automation/rhdh-image-*`, `automation/plugin-*`) are created by GitHub Actions — do not edit them manually.

## Environment Setup

Copy `scripts/env` to `scripts/private-env` and populate all values before running `make install`. The `private-env` file is gitignored — **never commit it**.

Required CLI tools: `oc`, `kubectl`, `yq`, `argocd`, `cosign`, `openssl`, `envsubst`

## Code Standards

- **ShellCheck**: Enforced on every PR via `shellcheck.yaml`. Run locally before pushing.
- **Plugin tag format**: OCI plugin images in `charts/rhdh/values.yaml` use `bs_<backstage-version>__<plugin-version>` tags. Images are built in [`redhat-developer/rhdh-plugin-export-overlays`](https://github.com/redhat-developer/rhdh-plugin-export-overlays).
- **No secrets in git**: All credentials go through `private-env` or Kubernetes secrets created by `scripts/setup-secrets.sh`.

## Testing

Tests are in `tests/` using Playwright + pytest (Python ≥3.11, managed with `uv`).

Required env vars: `RHDH_BASE_URL`, `RHDH_ENVIRONMENT`, `ROLLING_DEMO_TEST_USERNAME`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET`

Test markers:

- `smoke` — no authentication required
- `auth_required` — needs a logged-in Keycloak session

## Key Files

| Path                       | Purpose                                                       |
| -------------------------- | ------------------------------------------------------------- |
| `charts/rhdh/values.yaml`  | Primary config — all plugin versions and RHDH image live here |
| `gitops/application.yaml`  | ArgoCD Application definition                                 |
| `scripts/env`              | Environment variable template (copy → `private-env`)          |
| `scripts/setup-secrets.sh` | Creates all K8s secrets; edit here when adding credentials    |
| `deps/*.yaml`              | Operator dependency manifests (NFD, GPU, Pipelines, GitOps)   |
| `docs/SETUP_GUIDE.md`      | Full setup instructions                                       |
| `docs/TESTING.md`          | Test environment setup and local run guide                    |

## Nightly Automation

| Workflow                  | Branch        | What it does                                                      |
| ------------------------- | ------------- | ----------------------------------------------------------------- |
| `plugins-updater.yaml`    | `development` | Opens one PR per plugin with a new OCI tag                        |
| `rhdh-image-updater.yaml` | `development` | Opens a PR when a new `next-<hash>` RHDH image appears on Quay.io |
| `nightly.yml`             | `main`        | Runs Playwright E2E tests; sends Slack alert on failure           |

When updating plugin config in `charts/rhdh/values.yaml`, always cross-reference the RHDH release notes for the target version: `https://docs.redhat.com/en/documentation/red_hat_developer_hub/<version>/html/red_hat_developer_hub_release_notes` (e.g. replace `<version>` with `1.9`).

## Subagents

Use subagents for focused, context-heavy tasks:

- **rhdh-config-reviewer**: Reviews `charts/rhdh/values.yaml` changes, validates plugin tag formats, checks for config regressions, and cross-references RHDH release notes. Invoke with: `Use the rhdh-config-reviewer subagent to review my values.yaml changes.`
- **workflow-analyst**: Analyzes `.github/workflows/` files for correctness, secret usage, and automation logic. Invoke with: `Use the workflow-analyst subagent to check this workflow.`
- **tester**: Runs the Playwright E2E test suite and reports results. Invoke with: `Use the tester subagent to run the E2E tests.`
