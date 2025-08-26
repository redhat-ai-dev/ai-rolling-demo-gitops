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
# RHDH_CLUSTER_ROUTER_BASE: should contain the domain suffix of all the
# OCP routes.
export RHDH_CLUSTER_ROUTER_BASE="apps.mycluster.openshift.com"
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
export KEYCLOAK_METADATA_URL="https://keycloak-rh-sso.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/auth/realms/${KEYCLOAK_REALM}"
export KEYCLOAK_BASE_URL="https://keycloak-rh-sso.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/auth"

# NOTE: For Ollama & Lightspeed we rely on 3Scale. Therefore,
# to setup your Ollama & Lightspeed tokens & urls you'll need
# first to register an application on the 3Scale service.
# Check more info here: https://docs.redhat.com/en/documentation/red_hat_3scale_api_management/2.11/html/getting_started/first-steps-with-threescale_configuring-your-api

# Ollama secrets
# Hint:: Per RHDHPAI case the Lightspeed and Ollama tokens can be found in https://console-openshift-console.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com/
# Namespace: rolling-demo-ns
# Secret: lightspeed-secrets (keys are identical with the env var names below).
# Remember to Base64 Decode the values for the various environment variables stored in the `keycloak-secrets`.
export OLLAMA_TOKEN="your-ollama-token"
export OLLAMA_URL="https://ollama-model-service-apicast-production.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com:443/v1"

# Lightspeed secrets
export LIGHTSPEED_URL="your-lightspeed-token"
export LIGHTSPEED_TOKEN="https://ibm-granite-8b-code-instruct-3scale-apicast-production.apps.rosa.redhat-ai-dev.m6no.p3.openshiftapps.com"

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
