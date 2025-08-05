## Rolling demo setup

Here are the steps required to setup an instance of the rolling demo on your own:

### Pre-requisites

Your cluster should be of type `g5.4xlarge` or bigger. Additionally, to install the demo your cluster should have already installed the following operators:

- [Openshift Gitops](https://www.redhat.com/en/technologies/cloud-computing/openshift/gitops)
- [Openshift Pipelines](https://www.redhat.com/en/technologies/cloud-computing/openshift/pipelines)
- [Node Feature Discovery](https://docs.redhat.com/en/documentation/openshift_container_platform/4.10/html/specialized_hardware_and_driver_enablement/node-feature-discovery-operator), create a `NodeFeatureDiscovery` instance (with default values) and wait until its `Available`.
- [Nvidia GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html), create a `ClusterPolicy` CR and wait until is `Ready` (~ 5mins).

After you have installed the above pre-reqs, you'll have to:

- Clone the [odh-kubeflow-model-registry-setup](https://github.com/redhat-ai-dev/odh-kubeflow-model-registry-setup) repo.
- Run `oc apply -f ./kustomize-rhoai/` from its root directory.
- Wait until the job in the `odh-kubeflow-model-registry-setup` project is completed.

#### Dependencies

In order to be able to set everything up you need to have installed:

- [yq](https://github.com/mikefarah/yq)
- [cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- [oc](https://docs.redhat.com/en/documentation/openshift_container_platform/4.8/html/cli_tools/openshift-cli-oc)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)

#### Setup the `private-env` file

- Create a file called `private-env` inside the [scripts/](./scripts/) directory and copy all the contents of the [scripts/env](./scripts/env) file there.

- Your `scripts/private-env` should look like:

```bash
# Github secrets
# For more information on how to setup your github app
# you can take a look here:
# https://github.com/redhat-ai-dev/ai-rhdh-installer/blob/main/docs/APP-SETUP.md
export GITHUB_APP_APP_ID="your-github-apps-app-id"
export GITOPS_GIT_TOKEN="your-github-token"
export GITOPS_GIT_ORG="your-github-org-name"
export GITHUB_APP_CLIENT_ID="your-github-app-client-id"
export GITHUB_APP_CLIENT_SECRET="your-github-app-client-secret"
export GITHUB_APP_WEBHOOK_URL="your-github-app-webhook-url"
export GITHUB_APP_WEBHOOK_SECRET="your-github-app-webhook-secret"
export GITHUB_APP_PRIVATE_KEY="your-github-org-name"

# ArgoCD secrets
export ARGOCD_USER="your-user" # default value is "admin"

# RHDH secrets
export BACKEND_SECRET="a-randomly-generated-string"
export RHDH_CLUSTER_ROUTER_BASE="example: apps.mycluster.openshift.com"
export RHDH_BASE_URL="https://rolling-demo-backstage-rolling-demo-ns.${RHDH_CLUSTER_ROUTER_BASE}" # this is the route for the RHDH console 
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
# Could be an instance external to your cluster.
export KEYCLOAK_METADATA_URL="your-instance's-url/auth/realms/your-realm"
export KEYCLOAK_CLIENT_ID="your-client-id"
export KEYCLOAK_REALM="your-realm"
export KEYCLOAK_BASE_URL="your-instance's-url/auth"
export KEYCLOAK_LOGIN_REALM="your-realm"
export KEYCLOAK_CLIENT_SECRET="your-secret"

# Ollama secrets
# Again here is ok to use an existing ollama service external to
# your cluster
export OLLAMA_TOKEN="your-ollama-token"
export OLLAMA_URL="ollama-url"

# Lightspeed secrets
# Same as keycloak and ollama here you can use an external instance
export LIGHTSPEED_URL="your-lightspeed-token"
export LIGHTSPEED_TOKEN="lightspeed-url"

# Postgres secrets
export LIGHTSPEED_POSTGRES_PASSWORD="your-preffered-lightspeed-psql-password"
export LIGHTSPEED_POSTGRES_USER="your-preffered-lightspeed-psql-username"
export LIGHTSPEED_POSTGRES_DB="your-preffered-lightspeed-psql-dbname"
```

### Installation

After the required steps above you can simply use the [prepare-rolling-demo.sh](./scripts/prepare-rolling-demo.sh) script to prepare everything you need for the installation.

```bash
cd scripts; bash prepare-rolling-demo.sh
```

Finally you have to create your argocd application in the `openshift-gitops` namespace:

```bash
kubectl apply -f gitops/application.yaml -n openshift-gitops
```
