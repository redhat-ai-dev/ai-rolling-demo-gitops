# RedHat AI Dev — Organizational Context

This file provides context about how `ai-rolling-demo-gitops` fits within the broader `redhat-ai-dev` GitHub organization. Use it when a task requires understanding upstream dependencies or related repositories.

## This Repository's Role

`ai-rolling-demo-gitops` is the **operational GitOps source** for the AI Rolling Demo cluster. It does not contain application code — it contains Helm values, ArgoCD manifests, Kubernetes operator configs, and automation scripts that together drive a live OpenShift deployment. Changes here have direct production impact via ArgoCD auto-sync.

## Component Map

| Component                                                                    | Source Repository                                                                                                                                                          | How It Lands Here                                                                                                                                                                          |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| RHDH Helm chart                                                              | [redhat-developer/rhdh-chart](https://github.com/redhat-developer/rhdh-chart)                                                                                              | Helm dependency in `charts/rhdh/Chart.yaml`                                                                                                                                                |
| RHDH community image                                                         | `quay.io/rhdh-community/rhdh`                                                                                                                                              | Image tag in `charts/rhdh/values.yaml`, updated by `rhdh-image-updater.yaml`                                                                                                               |
| AI software templates                                                        | [redhat-ai-dev/ai-lab-template](https://github.com/redhat-ai-dev/ai-lab-template)                                                                                          | Referenced as RHDH catalog location                                                                                                                                                        |
| Model Catalog Bridge                                                         | [redhat-ai-dev/model-catalog-bridge](https://github.com/redhat-ai-dev/model-catalog-bridge)                                                                                | Plugin OCI image in `values.yaml`                                                                                                                                                          |
| RHDH AI plugin (`catalog-backend-module-rhdh-ai`)                            | [redhat-ai-dev/rhdh-plugins](https://github.com/redhat-ai-dev/rhdh-plugins)                                                                                                | Plugin OCI image in `values.yaml`                                                                                                                                                          |
| MCP Integrations plugin                                                      | [catalog-backend-module-model-catalog](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/ai-integrations/plugins/catalog-backend-module-model-catalog) | Plugin OCI image in `values.yaml`                                                                                                                                                          |
| Lightspeed plugins (`lightspeed`, `lightspeed-backend`, `lightspeed-common`) | [redhat-developer/rhdh-plugins — lightspeed workspace](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/lightspeed/plugins)                           | Plugin OCI images in `values.yaml`; `lightspeed` is the frontend, `lightspeed-backend` handles API calls, `lightspeed-common` provides shared utilities                                    |
| RHOAI/ODH dev setup                                                          | [redhat-ai-dev/odh-kubeflow-model-registry-setup](https://github.com/redhat-ai-dev/odh-kubeflow-model-registry-setup)                                                      | Not deployed by this repo; used to provision an external RHOAI instance (Model Registry + LlamaStack) that the Model Catalog Bridge connects to                                            |
| Plugin build & image registry                                                | [redhat-developer/rhdh-plugin-export-overlays](https://github.com/redhat-developer/rhdh-plugin-export-overlays)                                                            | Builds all dynamic plugin OCI images and publishes them with `bs_<backstage-version>__<plugin-version>` tags; this is where new image references originate before landing in `values.yaml` |
| Plugin updater action                                                        | [redhat-ai-dev/rhdh-plugin-gitops-updater](https://github.com/redhat-ai-dev/rhdh-plugin-gitops-updater)                                                                    | Called from `plugins-updater.yaml`                                                                                                                                                         |

## Infrastructure

| System                                                                  | Role                                                                                                                                                             |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenShift (ROSA)                                                        | Cluster hosting the demo                                                                                                                                         |
| ArgoCD                                                                  | GitOps controller — syncs this repo to the cluster                                                                                                               |
| Red Hat SSO / Keycloak                                                  | Authentication provider for RHDH                                                                                                                                 |
| RHOAI (OpenShift AI)                                                    | External model serving; required for Model Catalog Bridge                                                                                                        |
| [Lightspeed Stack](https://github.com/lightspeed-core/lightspeed-stack) | FastAPI service that powers the Lightspeed AI chat; wraps LLM providers (including Llama Stack internally) — Llama Stack is not a direct dependency of this repo |
| Quay.io (`rhdhpai-rolling-demo`)                                        | OCI registry for plugin images                                                                                                                                   |
| OpenShift Pipelines (Tekton)                                            | CI/CD engine for software template apps                                                                                                                          |

## Cross-Repo Automation

### lightspeed-configs → ai-rolling-demo-gitops

The [`redhat-ai-dev/lightspeed-configs`](https://github.com/redhat-ai-dev/lightspeed-configs) repository owns the Lightspeed Stack and Llama Stack configuration files. Its [`sync-gitops.yml`](https://github.com/redhat-ai-dev/lightspeed-configs/blob/main/.github/workflows/sync-gitops.yml) workflow creates a **one-way sync** into this repo:

- **Trigger**: Push to `main` in `lightspeed-configs` (on relevant config files) or manual `workflow_dispatch`
- **What it syncs**: Generates ConfigMap manifests and extracts image versions for `llama-stack`, `lightspeed-core`, and `rag-content`
- **Artifacts synced**: `lightspeed-stack-config.yaml`, `llama-stack-config.yaml`, `rolling-demo-sidecars-job.yaml`, `rhdh-profile.py`
- **How**: Opens a PR against the **`development`** branch of this repo with the updated manifests and image versions

When reviewing PRs that touch Lightspeed or Llama Stack config files, check whether they originated from this automation before editing them manually.

### ai-rolling-demo-gitops internal automation

| Workflow                  | Branch        | What it does                                                                                                                                                  |
| ------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `plugins-updater.yaml`    | `development` | Opens one PR per plugin with a new OCI tag; uses the [rhdh-plugins-gitops-updater](https://github.com/redhat-ai-dev/rhdh-plugin-gitops-updater) GitHub Action |
| `rhdh-image-updater.yaml` | `development` | Opens a PR when a new `next-<hash>` RHDH image appears on Quay.io                                                                                             |
| `nightly.yml`             | `main`        | Runs Playwright E2E tests; sends Slack alert on failure                                                                                                       |

## Key Constraints (Inherited from Org Decisions)

- **GitHub only**: Demo software templates only support GitHub as the target SCM.
- **Fixed GitHub org**: All demo apps are created under the `ai-rolling-demo` GitHub organization.
- **Fixed Quay org**: Plugin and app images go to `quay.io/rhdhpai-rolling-demo`.
- **RHOAI dependency**: Model Catalog Bridge requires an external RHOAI instance with registered models.
- **24-hour app TTL**: A [pruner cronjob](https://github.com/redhat-ai-dev/rosa-gitops/tree/main/argocd-pruner) removes software template applications and their GitHub/OpenShift resources after 24 hours.
