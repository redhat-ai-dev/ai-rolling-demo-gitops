## Rolling demo setup

Here are the steps required to setup an instance of the rolling demo on your own:

### Pre-requisites

You need an [OpenShift cluster (version 4.19+)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/web_console/index) of type `g5.2xlarge` or bigger.

You have cloned locally the [odh-kubeflow-model-registry-setup](https://github.com/redhat-ai-dev/odh-kubeflow-model-registry-setup) repo.

#### Dependencies

In order to be able to set everything up you need to have installed:

- [yq](https://github.com/mikefarah/yq)
- [cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- [oc](https://docs.redhat.com/en/documentation/openshift_container_platform/4.8/html/cli_tools/openshift-cli-oc)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [argocd](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [openssl](https://github.com/openssl/openssl)
- [envsubst](https://github.com/a8m/envsubst)

#### Setup the `private-env` file

- Create a file called `private-env` inside the [scripts/](../scripts/) directory and copy all the contents of the [scripts/env](../scripts/env) file there.

- Your `scripts/private-env` should look like:

```bash
# GitOps repo settings
# GITOPS_REPO_URL: the URL of the gitops repository. If you are working
# from a fork, set this to your fork's URL.
export GITOPS_REPO_URL="https://github.com/your-org/ai-rolling-demo-gitops.git"
# GITOPS_TARGET_REVISION: the git branch ArgoCD will track.
export GITOPS_TARGET_REVISION="dev"
# ODH_SETUP_DIR: the local path to the cloned odh-kubeflow-model-registry-setup repo.
export ODH_SETUP_DIR="/path/to/odh-kubeflow-model-registry-setup"
# RHDH_NAMESPACE: the namespace where RHDH and related resources are deployed.
export RHDH_NAMESPACE="rolling-demo-ns"
# ARGOCD_APP_NAME: the argoCD application name.
export ARGOCD_APP_NAME="rolling-demo"

# Github secrets
# For more information on how to setup your github app
# you can take a look here:
# https://github.com/redhat-ai-dev/ai-rhdh-installer/blob/main/docs/APP-SETUP.md
export GITHUB_APP_APP_ID="your-github-apps-app-id"
export GITOPS_GIT_TOKEN="your-github-token"
# GITOPS_GIT_ORG: the GitHub organization used for catalog discovery in RHDH.
export GITOPS_GIT_ORG="your-github-org-name"
export GITHUB_APP_CLIENT_ID="your-github-app-client-id"
export GITHUB_APP_CLIENT_SECRET="your-github-app-client-secret"
export GITHUB_APP_WEBHOOK_URL="your-github-app-webhook-url"
export GITHUB_APP_WEBHOOK_SECRET="your-github-app-webhook-secret"
export GITHUB_APP_PRIVATE_KEY="your-github-app-private-key"

# ArgoCD secrets
export ARGOCD_USER="your-user" # default value is "admin"

# RHDH secrets
export BACKEND_SECRET="a-randomly-generated-string"
# RHDH_CLUSTER_ROUTER_BASE: the domain suffix of all OCP routes.
# This is used to derive the RHDH URL and is injected as an ArgoCD
# Helm parameter override for the clusterRouterBase chart value.
export RHDH_CLUSTER_ROUTER_BASE="apps.mycluster.openshift.com"

# RHDH Postgres Secrets - any valid password strings for these two env vars will do
export POSTGRESQL_POSTGRES_PASSWORD="your-preffered-postgres-pass"
export POSTGRESQL_USER_PASSWORD="your-preffered-user-pass"

# Quay.io secrets
# For more information on how to setup quay.io you check the doc
# here: https://github.com/redhat-ai-dev/ai-rhdh-installer/blob/main/docs/APP-SETUP.md#quay-setup
export QUAY_DOCKERCONFIGJSON="your-quay.io-dockerconfig.json"

# KeyCloak (RH SSO) secrets
# In this area you can point to an already existing keycloak instance.
#
# Hint:: As per RHDHPAI use case You could replace the values below with the ones in
# the Dev Instance: https://console-openshift-console.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/
# Namespace: rolling-demo-ns and Secret: keycloak-secrets.
# Remember to Base64 Decode the values for the various environment variables stored in the `keycloak-secrets`.
export KEYCLOAK_CLIENT_ID="your-client-id"
export KEYCLOAK_CLIENT_SECRET="your-secret"
# KEYCLOAK_REALM: The realm you want to use for your deployment.
# Check more info for realms here: https://www.keycloak.org/docs/latest/server_admin/index.html#_configuring-realms
export KEYCLOAK_REALM="your-realm"
export KEYCLOAK_LOGIN_REALM=${KEYCLOAK_REALM}
export KEYCLOAK_METADATA_URL="https://your-keycloak-host/auth/realms/${KEYCLOAK_REALM}"
export KEYCLOAK_BASE_URL="https://your-keycloak-host/auth"

# Llama Stack secrets (for Lightspeed Core Service)
# Hint:: Per RHDHPAI case the Llama Stack tokens can be found in https://console-openshift-console.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/
# Secret: llama-stack-secrets (keys are identical with the env var names below).
# Remember to Base64 Decode the values for the various environment variables stored in the `llama-stack-secrets`.
export VLLM_URL="https://meta-llama-31-8b-3scale-apicast-production.your-3scale-host:443/v1"
export VLLM_API_KEY="your-llama-stack-token"
# VALIDATION_PROVIDER: The LLM provider type - must be one of: vllm, ollama, openai
export VALIDATION_PROVIDER="vllm"
# VALIDATION_MODEL_NAME: The name of the model to use for validation
export VALIDATION_MODEL_NAME="llama-31-8b-version1"

# Postgres secrets
export LIGHTSPEED_POSTGRES_PASSWORD="your-preffered-lightspeed-psql-password"
export LIGHTSPEED_POSTGRES_USER="your-preffered-lightspeed-psql-username"
export LIGHTSPEED_POSTGRES_DB="your-preffered-lightspeed-psql-dbname"
```

#### `env` Changelog

This section tracks variables added or removed between releases. Use it to update your `private-env` when upgrading.

---

##### v0.1.0 → v0.2.0

**Removed:**

- `ADMIN_TOKEN`: No longer needed.

---

##### v0.2.0 → v0.2.1 → v0.2.2

No changes.

---

##### v0.2.2 → v0.3.0

**Added:**

- `RHDH_BASE_URL` — RHDH console URL (RHDH secrets section)
- `OLLAMA_TOKEN`, `OLLAMA_URL` — new **Ollama secrets** section
- `LIGHTSPEED_URL`, `LIGHTSPEED_TOKEN` — new **Lightspeed secrets** section
- `LIGHTSPEED_POSTGRES_PASSWORD`, `LIGHTSPEED_POSTGRES_USER`, `LIGHTSPEED_POSTGRES_DB` — new **Postgres secrets** section

---

##### v0.3.0 → v0.5.0

No changes.

---

##### v0.5.0 → v1.0.0 (current)

**Added:**

- New **GitOps repo settings** section: `GITOPS_REPO_URL`, `GITOPS_TARGET_REVISION`, `ODH_SETUP_DIR`, `RHDH_NAMESPACE` (defaults to `rolling-demo-ns`)
- `RHDH_CLUSTER_ROUTER_BASE` — cluster domain suffix, replaces `RHDH_CALLBACK_URL` and `RHDH_BASE_URL`
- New **Llama Stack secrets** section: `VLLM_URL`, `VLLM_API_KEY`, `VALIDATION_PROVIDER`, `VALIDATION_MODEL_NAME` — replaces the Ollama and Lightspeed URL/token variables

**Removed:**

- `ARGOCD_PASSWORD`, `ARGOCD_HOSTNAME`, `ARGOCD_TOKEN` — ArgoCD section now only requires `ARGOCD_USER`
- `RHDH_CALLBACK_URL`, `RHDH_BASE_URL`
- `OLLAMA_TOKEN`, `OLLAMA_URL` — entire Ollama section removed
- `LIGHTSPEED_URL`, `LIGHTSPEED_TOKEN` — replaced by Llama Stack section

### Installation

After configuring your `scripts/private-env` file, run the setup from the repository root:

```bash
make install
```

The `setup.sh` script automates the entire setup process by calling focused subscripts in order:

1. [`install-operators.sh`](../scripts/install-operators.sh) — installs the required operators (OpenShift GitOps, OpenShift Pipelines, Node Feature Discovery, NVIDIA GPU) and creates the NFD instance and NVIDIA ClusterPolicy.
2. [`setup-rhoai.sh`](../scripts/setup-rhoai.sh) — applies the ODH Kubeflow Model Registry kustomize and waits for the setup job to complete.
3. [`setup-argocd.sh`](../scripts/setup-argocd.sh) — retrieves ArgoCD admin credentials and generates an API token.
4. [`setup-namespaces.sh`](../scripts/setup-namespaces.sh) — creates the RHDH and LightSpeed Postgres namespaces.
5. [`setup-sa-tokens.sh`](../scripts/setup-sa-tokens.sh) — creates service accounts and generates their tokens.
6. [`setup-secrets.sh`](../scripts/setup-secrets.sh) — creates all required Kubernetes secrets in the target namespaces.
7. [`setup-pipelines.sh`](../scripts/setup-pipelines.sh) — configures the Cosign signing secret and runs the Tekton pipeline setup.
8. [`apply-argocd-application.sh`](../scripts/apply-argocd-application.sh) — applies the ArgoCD Application with your configured `GITOPS_REPO_URL`, `GITOPS_TARGET_REVISION`, and `RHDH_CLUSTER_ROUTER_BASE` values.

#### Skipping steps

You can skip earlier steps if they have already been completed on your cluster:

- `SKIP_INSTALL_DEPS=true` — skips operator and instance installation.
- `SKIP_RHOAI_SETUP=true` — skips the ODH Kubeflow Model Registry setup.

For example, to jump straight to the rolling demo preparation:

```bash
SKIP_INSTALL_DEPS=true SKIP_RHOAI_SETUP=true make install
```

#### Secondary instance

If there's an instance of RHDH Rolling Demo already existing on your cluster (with Cosign keys, TektonConfig, and Pipelines-as-Code secrets already configured), you can deploy an additional instance by providing a different namespace and ArgoCD application name:

```bash
RHDH_NAMESPACE=my-secondary-ns \
ARGOCD_APP_NAME=my-secondary-app-name \
IS_SECONDARY_INSTANCE=true \
SKIP_INSTALL_DEPS=true \
SKIP_RHOAI_SETUP=true \
make install
```

`setup.sh` will automatically compute `RHDH_BASE_URL` and `RHDH_CALLBACK_URL` from `ARGOCD_APP_NAME`, `RHDH_NAMESPACE`, and `RHDH_CLUSTER_ROUTER_BASE`.

When `IS_SECONDARY_INSTANCE=true`:

- The Cosign signing secret is not regenerated.
- The TektonConfig `transparency.url` is not patched.
- The `pipelines-as-code-secret` and the LightSpeed Postgres secret in the `PAC_NAMESPACE` are not created.
- The ArgoCD Application is deployed with `global.isSecondaryInstance=true`.

#### Optional overrides

The following variables have built-in defaults and do not need to be set in `private-env` unless you want to change them. All operator channel and CSV defaults are based on OCP 4.20:

| Variable                        | Default                                   | Description                                                                                                                                                                      |
| ------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ARGOCD_NAMESPACE`              | `openshift-gitops`                        | Namespace where ArgoCD (OpenShift GitOps) is installed.                                                                                                                          |
| `PAC_NAMESPACE`                 | `openshift-pipelines`                     | Namespace where OpenShift Pipelines and Pipelines-as-Code run.                                                                                                                   |
| `LIGHTSPEED_POSTGRES_NAMESPACE` | `lightspeed-postgres`                     | Namespace where the LightSpeed PostgreSQL instance is deployed.                                                                                                                  |
| `GITOPS_OPERATOR_CHANNEL`       | `latest`                                  | Subscription channel for the OpenShift GitOps operator.                                                                                                                          |
| `GITOPS_STARTING_CSV`           | `openshift-gitops-operator.v1.19.1`       | Starting CSV for the OpenShift GitOps operator.                                                                                                                                  |
| `PIPELINES_OPERATOR_CHANNEL`    | `latest`                                  | Subscription channel for the OpenShift Pipelines operator.                                                                                                                       |
| `PIPELINES_STARTING_CSV`        | `openshift-pipelines-operator-rh.v1.21.0` | Starting CSV for the OpenShift Pipelines operator.                                                                                                                               |
| `NFD_OPERATOR_CHANNEL`          | `stable`                                  | Subscription channel for the Node Feature Discovery operator.                                                                                                                    |
| `NFD_STARTING_CSV`              | auto-detected                             | Starting CSV for the Node Feature Discovery operator. Auto-detected from the cluster catalog for the active `NFD_OPERATOR_CHANNEL`. Set explicitly to pin to a specific version. |
| `GPU_OPERATOR_CHANNEL`          | `v25.10`                                  | Subscription channel for the NVIDIA GPU operator.                                                                                                                                |
| `GPU_STARTING_CSV`              | `gpu-operator-certified.v25.10.1`         | Starting CSV for the NVIDIA GPU operator.                                                                                                                                        |

These can be set in `private-env` or passed directly on the command line:

```bash
PAC_NAMESPACE=my-pipelines-ns make install
```

#### Customize operator channels and CSV versions

To see the available subscription channels and current CSV for any operator, query the `PackageManifest` from your cluster:

```bash
# List all available channels for an operator
oc get packagemanifest <package-name> -n openshift-marketplace \
  -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}'

# Get the current CSV for a specific channel
oc get packagemanifest <package-name> -n openshift-marketplace \
  -o jsonpath='{.status.channels[?(@.name=="<channel-name>")].currentCSV}'
```

#### Working from a fork

If you are working from a fork of this repository, set these env vars in your `private-env`:

```bash
export GITOPS_REPO_URL="https://github.com/your-user/ai-rolling-demo-gitops.git"
export GITOPS_TARGET_REVISION="main"
```

The `setup.sh` script uses `yq` to inject these values into `gitops/application.yaml` at apply time, so the file in git is not modified.

#### How clusterRouterBase is configured

The `clusterRouterBase` value in `charts/rhdh/values.yaml` is a Helm chart value and cannot use `${ENV_VAR}` substitution at runtime. Instead, `setup.sh` injects it as an ArgoCD Helm parameter override when applying `gitops/application.yaml`. This means the value from `RHDH_CLUSTER_ROUTER_BASE` in your `private-env` is used without modifying any files in git.

### Running tests locally

See [docs/TESTING.md](./TESTING.md) for setup instructions, required environment variables, and how to run the tests locally.
