#!/bin/bash

# ----------- Constants ----------- #

RHDH_NAMESPACE="rolling-demo-ns"
ARGOCD_NAMESPACE="openshift-gitops"
PAC_NAMESPACE="openshift-pipelines"
LIGHTSPEED_POSTGRES_NAMESPACE="lightspeed-postgres"

# ----------- Utils ----------- #

# check_dependencies: verifies that the system has all deps installed
check_dependencies() {
  local missing=()
  local tools=("cosign" "argocd" "oc" "kubectl" "yq")


  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "* '$tool' is not installed or not in PATH."
      missing+=("$tool")
    else
      echo "* '$tool' is installed."
    fi
  done

  if (( ${#missing[@]} )); then
    echo
    echo "* Missing required tools: ${missing[*]}"
    echo "* Please install them and try again."
    echo "FAIL"
    exit 1
  fi

  echo "* All dependencies are installed."
  echo "OK"
}

# create_project: creates a project in openshift
create_project() {
  local namespace="$1"

  if oc get project "$namespace" >/dev/null 2>&1; then
    echo "* Project '$namespace' already exists."
  else
    echo "* Creating project '$namespace'..."
    if oc new-project "$namespace"; then
      echo "* Project '$namespace' created successfully."
    else
      echo "* Failed to create project '$namespace'. Exiting."
      echo "FAIL"
      exit 1
    fi
  fi
  echo "OK"
}

# add_argocd_label: labels a given openshift project for argocd
add_argocd_label() {
  local namespace="$1"
  local argocd_namespace="${2:-openshift-gitops}"

  if ! oc label namespace "$namespace" "argocd.argoproj.io/managed-by=$argocd_namespace" --overwrite; then
    echo "* Failed to label namespace '$namespace'. Exiting."
    echo "FAIL"
    return 1
  fi

  echo "* Project '$namespace' labeled successfully."
  echo "OK"
}

# enable_argocd_admin_apiKey: Enables argoCD admin apiKey capability
enable_argocd_admin_apiKey() {
  local namespace="$1"
  local argocd_name="$2"
  local temp_file="argocd-patched.yaml"

  echo "* Exporting Argo CD CR from namespace '$namespace'..."
  if ! kubectl get argocd "$argocd_name" -n "$namespace" -o yaml > argocd.yaml; then
    echo "* Failed to fetch Argo CD CR. Exiting."
    echo "FAIL"
    exit 1
  fi

  if grep -q "accounts.admin: apiKey" argocd.yaml; then
    echo "* Argo CD CR already contains 'accounts.admin: apiKey'. Skipping patch."
  else
    echo "* Patching Argo CD CR to enable 'accounts.admin: apiKey'..."
    yq eval '.spec.extraConfig."accounts.admin" = "apiKey"' argocd.yaml > "$temp_file"

    echo "* Applying updated Argo CD CR..."
    if ! kubectl apply -f "$temp_file" -n "$namespace"; then
      echo "* Failed to apply patched CR. Exiting."
      rm -f "$temp_file"
      echo "FAIL"
      exit 1
    fi

    echo "* Cleaning up temporary files..."
    rm -f "$temp_file"

    echo "* Patch applied successfully."
    echo "OK"
  fi
}

# generate_argocd_api_token:: generates argoCD api key after logging in to the argocd server
generate_argocd_api_token() {
  local namespace="${1:-openshift-gitops}"

  echo "* Retrieving Argo CD creds..."
  get_argocd_admin_creds

  if ! argocd login "$ARGOCD_HOSTNAME" \
    --username admin \
    --password "$ARGOCD_PASSWORD" \
    --insecure \
    --skip-test-tls \
    --grpc-web; then
    echo "* Login failed."
    echo "FAIL"
    return 1
  fi

  echo "* Generating API token for admin account..."
  ARGOCD_API_TOKEN=$(argocd account generate-token --account admin)

  if [[ -z "$ARGOCD_API_TOKEN" ]]; then
    echo "* Failed to generate API token."
    return 1
  fi

  export ARGOCD_API_TOKEN
  echo "* ARGOCD_API_TOKEN exported for this session."
  echo "OK"
}

# create_sa_tokens: creates rhdh & k8s sa and their tokens
create_sa_tokens() {
  local namespace="$1"
  kubectl create serviceaccount k8s-sa -n "$namespace" 2>/dev/null || echo "* 'k8s-sa' already exists."
  kubectl create serviceaccount rhdh-sa -n "$namespace" 2>/dev/null || echo "*  'rhdh-sa' already exists."
  kubectl create serviceaccount mcp-actions-sa -n "$namespace" 2>/dev/null || echo "*  'mcp-actions-sa' already exists."

  echo "* Creating role binding for 'k8s-sa'..."
  kubectl create rolebinding k8s-admin-binding \
    --clusterrole=admin \
    --serviceaccount="$namespace:k8s-sa" \
    --namespace="$namespace" 2>/dev/null || echo "* Role binding already exists."

  kubectl create rolebinding k8s-reader-binding \
    --clusterrole=cluster-reader \
    --serviceaccount="$namespace:k8s-sa" \
    --namespace="$namespace" 2>/dev/null || echo "* Role binding already exists."

  echo "* Creating token for 'k8s-sa' (1 year)..."
  K8S_CLUSTER_TOKEN=$(kubectl create token k8s-sa -n "$namespace" --duration 8760h)

  echo "* Creating token for 'rhdh-sa'..."
  RHDH_SA_TOKEN=$(kubectl create token rhdh-sa -n "$namespace")

  echo "* Creating token for 'mcp-actions-sa'..."
  MCP_TOKEN=$(kubectl create token mcp-actions-sa -n "$namespace")

  export K8S_CLUSTER_TOKEN
  export RHDH_SA_TOKEN
  export MCP_TOKEN

  echo "* Service accounts and tokens created."
  echo "OK"
}

# get_argocd_admin_creds: fetches argocd admin password and argocd hostname
get_argocd_admin_creds() {
  local namespace="${1:-openshift-gitops}"

  echo "* Getting Argo CD admin password and hostname from namespace '$namespace'..."

  ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster -n "$namespace" -o jsonpath='{.data.admin\.password}' | base64 -d)
  ARGOCD_HOSTNAME=$(oc get route openshift-gitops-server -n "$namespace" -o jsonpath='{.status.ingress[0].host}')

  if [[ -z "$ARGOCD_PASSWORD" || -z "$ARGOCD_HOSTNAME" ]]; then
    echo "* Failed to retrieve Argo CD credentials. Exiting."
    return 1
  fi

  export ARGOCD_PASSWORD
  export ARGOCD_HOSTNAME

  echo "* Retrieved Argo CD admin credentials."
  echo "OK"
}

# configure_cosign_signing_secret: configures signing secret
configure_cosign_signing_secret() {
  local namespace="${1:-openshift-pipelines}"
  local random_pass

  random_pass=$(openssl rand -base64 30)

  echo "* Deleting existing 'signing-secrets' secret (if it exists)..."
  kubectl delete secret "signing-secrets" -n "$namespace" --ignore-not-found=true

  echo "* Generating new Cosign key pair into 'signing-secrets'..."
  if ! env COSIGN_PASSWORD="$random_pass" cosign generate-key-pair "k8s://$namespace/signing-secrets" >/dev/null; then
    echo "* Failed to generate cosign key pair. Exiting."
    echo "FAIL"
    return 1
  fi

  echo " * Marking 'signing-secrets' as immutable..."
  kubectl patch secret "signing-secrets" -n "$namespace" \
    --dry-run=client -o yaml \
    --patch='{"immutable": true}' \
    | kubectl apply -f - >/dev/null

  echo "* Cosign signing secret configured and made immutable."
  echo "OK"
}

# ----------- Setup ENV ----------- #

# Source the private env and check if all env vars
# have been set
source ./private-env
ENV_VARS=(
  "GITHUB_APP_APP_ID" \
  "GITHUB_APP_CLIENT_ID" \
  "GITHUB_APP_CLIENT_SECRET" \
  "GITHUB_APP_WEBHOOK_URL" \
  "GITHUB_APP_WEBHOOK_SECRET" \
  "GITHUB_APP_PRIVATE_KEY" \
  "ARGOCD_USER" \
  "BACKEND_SECRET" \
  "RHDH_CALLBACK_URL" \
  "POSTGRESQL_POSTGRES_PASSWORD" \
  "POSTGRESQL_USER_PASSWORD" \
  "QUAY_DOCKERCONFIGJSON" \
  "KEYCLOAK_METADATA_URL" \
  "KEYCLOAK_CLIENT_ID" \
  "KEYCLOAK_REALM" \
  "KEYCLOAK_BASE_URL" \
  "KEYCLOAK_LOGIN_REALM" \
  "KEYCLOAK_CLIENT_SECRET" \
  "OLLAMA_URL" \
  "OLLAMA_TOKEN" \
  "LIGHTSPEED_TOKEN" \
  "LIGHTSPEED_URL" \
)
for ENV_VAR in "${ENV_VARS[@]}"; do
  if [ -z "${!ENV_VAR}" ]; then
    echo "Error: $ENV_VAR is not set. Exiting..."
    exit 1
  fi
done

# ----------- Runbook ----------- #
# Pre-req: Check for dependencies
echo ""
echo "Checking for required dependencies..."
check_dependencies

# 1. Allow ArgoCD Admin to generate apiKey #
echo ""
echo "Setting up ArgoCD apiKey..."
enable_argocd_admin_apiKey "$ARGOCD_NAMESPACE" "$ARGOCD_NAMESPACE"

# 2. Export the ARGOCD_API_TOKEN
echo ""
echo "Generating the ARGOCD_API_TOKEN..."
generate_argocd_api_token "$ARGOCD_NAMESPACE"

# 3. Create project RHDH and LightSpeed Projects if they do not exist
echo ""
echo "Creating new project for $RHDH_NAMESPACE..."
create_project "$RHDH_NAMESPACE"

echo ""
echo "Creating new project for $LIGHTSPEED_POSTGRES_NAMESPACE..."
create_project $LIGHTSPEED_POSTGRES_NAMESPACE

echo ""
echo "Labeling $LIGHTSPEED_POSTGRES_NAMESPACE for ArgoCD management.."
add_argocd_label "$LIGHTSPEED_POSTGRES_NAMESPACE"

# 4. Create the necessary ServiceAccount token
echo ""
create_sa_tokens "$RHDH_NAMESPACE"
echo "Creating k8s and RHDH SA tokens..."

# ----------- Secrets Setup ----------- #
echo ""
echo "Setting up secrets on $RHDH_NAMESPACE and $PAC_NAMESPACE"

SECRET_NAME="github-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=GITHUB_APP_APP_ID="$GITHUB_APP_APP_ID" \
    --from-literal=GITHUB_APP_CLIENT_ID="$GITHUB_APP_CLIENT_ID" \
    --from-literal=GITHUB_APP_CLIENT_SECRET="$GITHUB_APP_CLIENT_SECRET" \
    --from-literal=GITHUB_APP_WEBHOOK_URL="$GITHUB_APP_WEBHOOK_URL" \
    --from-literal=GITHUB_APP_WEBHOOK_SECRET="$GITHUB_APP_WEBHOOK_SECRET" \
    --from-literal=GITHUB_APP_PRIVATE_KEY="$GITHUB_APP_PRIVATE_KEY" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="lightspeed-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=OLLAMA_URL="$OLLAMA_URL" \
    --from-literal=OLLAMA_TOKEN="$OLLAMA_TOKEN" \
    --from-literal=LIGHTSPEED_TOKEN="$LIGHTSPEED_TOKEN" \
    --from-literal=LIGHTSPEED_URL="$LIGHTSPEED_URL" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="kubernetes-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=K8S_CLUSTER_TOKEN="$K8S_CLUSTER_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="rolling-demo-postgresql"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=postgres-password="$POSTGRESQL_POSTGRES_PASSWORD" \
    --from-literal=password="$POSTGRESQL_USER_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="quay-pull-secret"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=.dockerconfigjson="$QUAY_DOCKERCONFIGJSON" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="keycloak-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=KEYCLOAK_METADATA_URL="$KEYCLOAK_METADATA_URL" \
    --from-literal=KEYCLOAK_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
    --from-literal=KEYCLOAK_REALM="$KEYCLOAK_REALM" \
    --from-literal=KEYCLOAK_BASE_URL="$KEYCLOAK_BASE_URL" \
    --from-literal=KEYCLOAK_LOGIN_REALM="$KEYCLOAK_LOGIN_REALM" \
    --from-literal=KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="rhdh-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=BACKEND_SECRET="$BACKEND_SECRET" \
    --from-literal=ADMIN_TOKEN="$RHDH_SA_TOKEN" \
    --from-literal=MCP_TOKEN="$MCP_TOKEN" \
    --from-literal=RHDH_BASE_URL="$RHDH_BASE_URL" \
    --from-literal=RHDH_CALLBACK_URL="$RHDH_CALLBACK_URL" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="ai-rh-developer-hub-env"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED="0" \
    --from-literal=RHDH_TOKEN="$RHDH_SA_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="argocd-secrets"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=ARGOCD_USER="$ARGOCD_USER" \
    --from-literal=ARGOCD_PASSWORD="$ARGOCD_PASSWORD" \
    --from-literal=ARGOCD_HOSTNAME="$ARGOCD_HOSTNAME" \
    --from-literal=ARGOCD_API_TOKEN="$ARGOCD_API_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="pipelines-as-code-secret"
echo -n "* $SECRET_NAME secret: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$PAC_NAMESPACE" \
    --from-literal=github-application-id="$GITHUB_APP_APP_ID" \
    --from-literal=github-private-key="$GITHUB_APP_PRIVATE_KEY" \
    --from-literal=webhook.secret="$GITHUB_APP_WEBHOOK_SECRET" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="lightspeed-postgres-info"
echo -n "* $SECRET_NAME secret in $LIGHTSPEED_POSTGRES_NAMESPACE: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=user="$LIGHTSPEED_POSTGRES_USER" \
    --from-literal=password="$LIGHTSPEED_POSTGRES_PASSWORD" \
    --from-literal=db-name="$LIGHTSPEED_POSTGRES_DB" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

SECRET_NAME="lightspeed-postgres-info"
echo -n "* $SECRET_NAME secret in $RHDH_NAMESPACE: "
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=user="$LIGHTSPEED_POSTGRES_USER" \
    --from-literal=password="$LIGHTSPEED_POSTGRES_PASSWORD" \
    --from-literal=db-name="$LIGHTSPEED_POSTGRES_DB" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
echo "OK"

# ------------- Setup Openshift Pipelines ------------- #
# Configure cosign
echo ""
echo "Configuring Cosign signing secrets in namespace '$namespace'..."
configure_cosign_signing_secret "$PAC_NAMESPACE"
echo "OK"

# Configure the pipelines setup - see scripts/configure-pipelines for more details
bash ./configure-pipelines.sh