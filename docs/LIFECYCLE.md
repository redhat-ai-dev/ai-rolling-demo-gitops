# RHDH AI Rolling Demo Gitops Development Lifecycle & Maintainance

The `ai-rolling-demo-gitops` repository is a gitops project managing two different instances of RHDH:

- The AI Rolling Demo: It targets to the `main` branch of the current repo.
- The RHDH AI Development: It targets to the `development` branch of the current repo.

## Branch Strategy

More specifically:

| Branch        | ArgoCD Application | Namespace            | Purpose                                |
| ------------- | ------------------ | -------------------- | -------------------------------------- |
| `main`        | `rolling-demo`     | `rolling-demo-ns`    | Production instance, tracks `HEAD`     |
| `development` | `rhdhai-rhdh-dev`  | `rhdhai-development` | Staging instance, tracks `development` |

## Development Process

1. **Develop**: New changes (plugin updates, config changes, chart updates) are committed to the `development` branch.
2. **Test**: For each PR against `development` and `main` we run all tests available in our testing suite (see [docs/TESTING.md](./TESTING.md) for more details).
3. **Validate**: Once new changes are merged, the `rhdhai-rhdh-dev` ArgoCD application will automatically get synced from the `development` branch, deploying the changes to the `rhdhai-development` namespace. This allows us to validate that the newly introduced changes are working as expected in a proper RHDH environment.
4. **Promote**: After each release's Feature Freeze has passed, all changes are merged into `main` (see our [Release Process](#release-process) for more details). The `rolling-demo` production application picks them up automatically via ArgoCD's self-heal and auto-sync policies.

### Release LifeCycle

A release in `ai-rolling-demo-gitops` reality is the act of promoting the `development` branch to `main`. The release process has specific stages during the release cycle of each RHDH version.

### 1. Pre - FF

During the pre-feature freeze stage, we are focusing on the `development` branch and our goal is to include there all the necessary changes for all the new features of the next RHDH realease.

### 2. Between FF and CF

Once ready, we are opening manually a PR to merge all `development` changes into `main` branch.

This can happen multiple times during this stage, in order to accommodate bug fixes, ad-hoc changes etc.

Before opening a promotion PR, confirm that the RHDH AI Development instance works as expected.

The deadline for this stage is the code freeze date.

### 3. Post CF - Create a new Rolling Demo Release

After the last changes have been merged into the `ai-rolling-demo-gitops` > `main` branch we are now ready to cut a new release for the AI Rolling Demo Gitops:

- The release name is identical to the corresponding RHDH version with a `v` prefix -> For example `v1.9.0`.

> [!IMPORTANT]
> A new release tag must be created before each RHDH Release Test Day

## Maintainance Automations

### The Plugin Updater (`plugins-updater.yaml`) Workflow

The plugin updater workflow runs nightly (and can be triggered manually via `workflow_dispatch`) to keep all RHDH plugins pinned to their latest available versions.

**What it does:**

1. Checks out the repository.
2. Runs the [`redhat-ai-dev/rhdh-plugin-gitops-updater`](https://github.com/redhat-ai-dev/rhdh-plugin-gitops-updater) action against `charts/rhdh/values.yaml`.
3. Scans all `oci:` plugin image tags with the prefixes `bs_`, and resolves the latest available version for each.
4. Opens a **pull request**, targeting the `development` branch, for each plugin that has a new version available.

This automation ensures that our gitops environment uses always the latest stable versions of rhdh plugins.
Once we have sufficiently validated the changes to the `development` branch and want to update the `main` branch, we will manually open a PR from `development` to `main`.

### The RHDH Image Updater (`rhdh-image-updater.yaml`) Workflow

Runs nightly (or manually via `workflow_dispatch`). Reads the current `MAJOR.MAJOR-MINOR` tag (e.g. `1.10-123`) from `charts/rhdh/values.yaml`, queries `quay.io/rhdh/rhdh-hub-rhel9` for the highest minor number available under the same `MAJOR.MAJOR-` prefix, and opens a PR against `development` if a newer tag is found. The major version is never bumped automatically. Any previously open PR for an older tag is automatically closed and its branch deleted.
