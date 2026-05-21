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

### Gitlab Plugins Not Suported

- The GitLab catalog discovery plugins (`catalog-backend-module-gitlab-dynamic` and `catalog-backend-module-gitlab-org-dynamic`) are currently disabled. The demo uses GitHub as its only SCM integration and these plugins require a `catalog.providers.gitlab.default.host` configuration that is not available.

### Model Catalog Bridge

- A pre-requisite for the model catalog bridge to work is a running Red Hat OpenShift AI instance, so the bridge can fetch all registered models and add them to RHDH as catalog entities.

### Limited Application Lifecycle

- In order to avoid overprovisioning of resources, the rolling demo uses a `pruner` cronjob that deletes all Software Template applications that are older than 24 hours. That means that all the openshift **and** github resources (deployments, repositories, argocd applications, etc.) are removed.

## Getting Started Guide

A guide covering RHDH fundamentals—navigation, the Software Catalog, TechDocs, APIs, Templates, Search, and Developer Lightspeed—can be found in [catalog-docs/getting-started-rhdh/index.md](./catalog-docs/getting-started-rhdh/index.md).

## Setup Rolling Demo on a Test Cluster

Some instructions on how to setup an instance of the rolling demo on your own can be found in [docs/SETUP_GUIDE.md](./docs/SETUP_GUIDE.md).

Two install paths are available:

| Command                 | Cluster requirements                     | What's included                                                                |
| ----------------------- | ---------------------------------------- | ------------------------------------------------------------------------------ |
| `make install`          | GPU-capable nodes (`g5.2xlarge`+), RHOAI | Full stack: RHDH, Lightspeed, Model Catalog Bridge, AI Software Templates      |
| `make install-no-rhoai` | Any OCP cluster (no GPU required)        | RHDH, Lightspeed, AI Software Templates — **no** Model Catalog Bridge or RHOAI |

Use `make install-no-rhoai` when you want to run the demo on a smaller cluster that does not have GPU nodes or Red Hat OpenShift AI.

## Testing

Information on the E2E test suite, required environment variables, and how to run tests locally can be found in [docs/TESTING.md](./docs/TESTING.md)

### Running tests locally

See [docs/TESTING.md](./docs/TESTING.md#running-ci-tests-locally) for setup instructions, required environment variables, and how to run the tests locally.

## Development & Maintenance

Information on the branch strategy, development process, release lifecycle, and maintenance automations can be found in [docs/LIFECYCLE.md](./docs/LIFECYCLE.md).

## Claude Code Integration

This repository includes configuration for [Claude Code](https://claude.ai/code) to assist with development tasks.

| File                                 | Purpose                                                                                                                           |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md`                          | Project-specific instructions for Claude Code (key commands, branch strategy, code standards)                                     |
| `CLAUDE-ORG.md`                      | Organizational context — how this repo fits within the broader `redhat-ai-dev` org, component map, and cross-repo automation      |
| `.claude/agents/pr-reviewer.md`      | Subagent for reviewing PRs — validates plugin OCI tag formats, checks config regressions, and cross-references RHDH release notes |
| `.claude/agents/tester.md`           | Subagent for running the Playwright E2E test suite and reporting results                                                          |
| `.claude/agents/workflow-analyst.md` | Subagent for analyzing `.github/workflows/` files for correctness, secret usage, and automation logic                             |

## Troubleshooting

### I cannot login to the rolling demo

If it is your first time accessing our cluster, keep in mind that we have an automation in place to register new users, so you might have to wait a few minutes for this process to be completed. If, after your second attempt you still have a problem accessing the rolling demo instance you please ping `team-rhdhpai` in the `#forum-rhdh-plugins-and-ai` slack channel.
