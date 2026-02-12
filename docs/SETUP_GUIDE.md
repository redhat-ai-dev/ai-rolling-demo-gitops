## Rolling demo setup

Here are the steps required to setup an instance of the rolling demo on your own:

### Pre-requisites

You need an [OpenShift cluster (version 4.19+)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/web_console/index) of type `g5.4xlarge` or bigger.

You have cloned locally the [odh-kubeflow-model-registry-setup](https://github.com/redhat-ai-dev/odh-kubeflow-model-registry-setup) repo.

#### Dependencies

In order to be able to set everything up you need to have installed:

- [yq](https://github.com/mikefarah/yq)
- [cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- [oc](https://docs.redhat.com/en/documentation/openshift_container_platform/4.8/html/cli_tools/openshift-cli-oc)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [argocd](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

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
# Defaults to "rolling-demo-ns" if not set.
export RHDH_NAMESPACE="rolling-demo-ns"

# Github secrets
# For more information on how to setup your github app
# you can take a look here:
# https://github.com/redhat-ai-dev/ai-rhdh-installer/blob/main/docs/APP-SETUP.md
export GITHUB_APP_APP_ID="your-github-apps-app-id"
export GITOPS_GIT_TOKEN="your-github-token"
# GITHUB_ORG: the GitHub organization used for catalog discovery in RHDH.
export GITHUB_ORG="your-github-org-name"
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
export RHDH_BASE_URL="https://rolling-demo-backstage-rolling-demo-ns.${RHDH_CLUSTER_ROUTER_BASE}"
export RHDH_CALLBACK_URL="${RHDH_BASE_URL}/api/auth/oidc/handler/frame"

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

# NOTE: For Ollama & Lightspeed we rely on 3Scale. Therefore,
# to setup your Ollama & Lightspeed tokens & urls you'll need
# first to register an application on the 3Scale service.
# Check more info here: https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.11/html/getting_started/first-steps-with-threescale_configuring-your-api

# Ollama secrets
# Hint:: Per RHDHPAI case the Lightspeed and Ollama tokens can be found in https://console-openshift-console.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/
# Namespace: rolling-demo-ns
# Secret: lightspeed-secrets (keys are identical with the env var names below).
# Remember to Base64 Decode the values for the various environment variables stored in the `lightpseed-secrets`.
export OLLAMA_TOKEN="your-ollama-token"
export OLLAMA_URL="https://ollama-model-service-apicast-production.your-3scale-host:443/v1"

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

### Installation

After configuring your `scripts/private-env` file, run the setup from the repository root:

```bash
make install
```

The `setup.sh` script automates the entire setup process:

1. Installs the required operators (OpenShift GitOps, [OpenShift Pipelines](), Node Feature Discovery, NVIDIA GPU).
2. Creates the NFD instance and NVIDIA ClusterPolicy.
3. Applies the ODH Kubeflow Model Registry kustomize and waits for the job to complete.
4. Runs [prepare-rolling-demo.sh](../scripts/prepare-rolling-demo.sh) to create service accounts, secrets, and configure pipelines.
5. Applies the ArgoCD Application with your configured `GITOPS_REPO_URL`, `GITOPS_TARGET_REVISION`, and `RHDH_CLUSTER_ROUTER_BASE` values.

#### Skipping steps

You can skip earlier steps if they have already been completed on your cluster:

- `SKIP_INSTALL_DEPS=true` — skips operator and instance installation.
- `SKIP_RHOAI_SETUP=true` — skips the ODH Kubeflow Model Registry setup.

For example, to jump straight to the rolling demo preparation:

```bash
SKIP_INSTALL_DEPS=true SKIP_RHOAI_SETUP=true make install
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
