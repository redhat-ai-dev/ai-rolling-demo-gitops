# RHDHPAI Rolling Demo GitOps

[![Nightly UI Tests](https://github.com/redhat-ai-dev/ai-rolling-demo-gitops/actions/workflows/nightly.yml/badge.svg)](https://github.com/redhat-ai-dev/ai-rolling-demo-gitops/actions/workflows/nightly.yml)
[![ShellCheck](https://github.com/redhat-ai-dev/ai-rolling-demo-gitops/actions/workflows/shellcheck.yaml/badge.svg)](https://github.com/redhat-ai-dev/ai-rolling-demo-gitops/actions/workflows/shellcheck.yaml)

The repository contains the gitops resources required to deploy an instance of the RHDHPAI rolling demo. The project is currently live at [rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com](https://rolling-demo-backstage-rolling-demo-ns.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com).

## Contents

The rolling demo combines the following components so far:

- The redhat developer hub chart ([rhdh-chart](https://github.com/redhat-developer/rhdh-chart)), in an attempt to keep the demo up-to-date with the latest changes of RHDH.
- The [AI software templates](https://github.com/redhat-ai-dev/ai-lab-template), a collection of Software Templates based on AI applications.
- The [Model Catalog Bridge](https://github.com/redhat-ai-dev/model-catalog-bridge) and the [catalog-backend-module-rhdh-ai](https://github.com/redhat-ai-dev/rhdh-plugins/tree/main/workspaces/rhdh-ai/plugins/catalog-backend-module-rhdh-ai) plugin. This mechanism provides a way to facilitate the seamless export of AI model records from Red Hat OpenShift AI and imports them into Red Hat Developer Hub (Backstage) as catalog entities.
- The [MCP Plugins](https://github.com/redhat-developer/rhdh-plugins/tree/main/workspaces/mcp-integrations), which provides a way for LLMs and AI applications to interact with Developer Hub.
- `Red Hat Developer Lightspeed` (Developer Lightspeed) is a virtual assistant powered by generative AI that offers in-depth insights into `Red Hat Developer Hub` (RHDH), including its wide range of capabilities.

## Capabilities & Limitations

### Access

- Access to the rolling demo is provided through Red Hat SSO.
- Every authenticated user has access to the AI software templates from the catalog. That said, you are able to choose the template you prefer and give it a try.

### AI Software Templates

- Currently our demo doesn't support deployment which require GPU.
- The rolling demo, currently supports only Github deployments. That said, you cannot use `Gitlab` as `Host Type` when installing the template.
- The github organization set to serve the demo is `ai-rolling-demo`, that said you need to keep it as the `Repository Owner`.
- Same applies for the `Image Organization` value. The `quay.io` repository corresponding to the demo is `rhdhpai-rolling-demo`.

### Model Catalog Bridge

- A pre-requisite for the model catalog bridge to work is a running Red Hat OpenShift AI instance, so the bridge can fetch all registered models and add them to RHDH as catalog entities.

### Limited Application Lifecycle

- In order to avoid overprovisioning of resources, the rolling demo uses a `pruner` cronjob that deletes all Software Template applications that are older than 24 hours. That means that all the openshift **and** github resources (deployments, repositories, argocd applications, etc.) are removed.

## Development Branch & Lifecycle

The repository maintains a `development` branch that serves as the integration branch for new changes before they reach the production (AI Rolling Demo) instance in RHDHAI DevCluster.

### Branch Strategy

| Branch        | ArgoCD Application | Namespace            | Purpose                                |
| ------------- | ------------------ | -------------------- | -------------------------------------- |
| `main`        | `rolling-demo`     | `rolling-demo-ns`    | Production instance, tracks `HEAD`     |
| `development` | `rhdhai-rhdh-dev`  | `rhdhai-development` | Staging instance, tracks `development` |

### Lifecycle

1. **Develop** — New changes (plugin updates, config changes, chart updates) are committed to the `development` branch.
2. **Validate** — The `rhdhai-rhdh-dev` ArgoCD application automatically syncs from the `development` branch, deploying the changes to the `rhdhai-development` namespace for testing.
3. **Promote** — Once validated, changes are merged into `main`. The `rolling-demo` production application picks them up automatically via ArgoCD's self-heal and auto-sync policies.

## Rolling demo setup

Some instructions on how to setup an instance of the rolling demo on your own can be found in [docs/SETUP_GUIDE.md](./docs/SETUP_GUIDE.md)

## Testing

Information on the E2E test suite, required environment variables, and how to run tests locally can be found in [docs/TESTING.md](./docs/TESTING.md)

## Troubleshooting

### I cannot login to the rolling demo

If it is your first time accessing our cluster, keep in mind that we have an automation in place to register new users, so you might have to wait a few minutes for this process to be completed. If, after your second attempt you still have a problem accessing the rolling demo instance you please ping `team-rhdhpai` in the `#forum-rhdh-plugins-and-ai` slack channel.
