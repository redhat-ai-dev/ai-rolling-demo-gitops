#!/bin/bash

# ----------- Constants ----------- #

RHDH_NAMESPACE="${RHDH_NAMESPACE:-rolling-demo-ns}"
ARGOCD_NAMESPACE="openshift-gitops"
PAC_NAMESPACE="openshift-pipelines"
LIGHTSPEED_POSTGRES_NAMESPACE="lightspeed-postgres"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/logging.sh"

# ----------- Utils ----------- #

# create_project: creates a project in openshift
create_project() {
  local namespace="$1"

  if oc get project "$namespace" >/dev/null 2>&1; then
    log "Project '$namespace' already exists."
  else
    log "Creating project '$namespace'..."
    if oc new-project "$namespace" >/dev/null 2>&1; then
      log "Project '$namespace' created successfully."
    else
      log "Failed to create project '$namespace'. Exiting."
      log_fail
      exit 1
    fi
  fi
}

# add_argocd_label: labels a given openshift project for argocd
add_argocd_label() {
  local namespace="$1"
  local argocd_namespace="${2:-openshift-gitops}"

  if ! oc label namespace "$namespace" "argocd.argoproj.io/managed-by=$argocd_namespace" --overwrite >/dev/null 2>&1; then
    log "Failed to label namespace '$namespace'. Exiting."
    log_fail
    return 1
  fi
  log "Project '$namespace' labeled successfully."
}

# enable_argocd_admin_apiKey: Enables argoCD admin apiKey capability
enable_argocd_admin_apiKey() {
  local namespace="$1"
  local argocd_name="$2"
  local temp_file="argocd-patched.yaml"

  log "Exporting Argo CD CR from namespace '$namespace'..."
  if ! kubectl get argocd "$argocd_name" -n "$namespace" -o yaml > argocd.yaml 2>/dev/null; then
    log "Failed to fetch Argo CD CR. Exiting."
    log_fail
    exit 1
  fi
  if grep -q "accounts.admin: apiKey" argocd.yaml; then
    log "Argo CD CR already contains 'accounts.admin: apiKey'. Skipping patch."
  else
    log "Patching Argo CD CR to enable 'accounts.admin: apiKey'..."
    yq eval '.spec.extraConfig."accounts.admin" = "apiKey"' argocd.yaml > "$temp_file"
    log "Applying updated Argo CD CR..."
    if ! kubectl apply -f "$temp_file" -n "$namespace" >/dev/null 2>&1; then
      log "Failed to apply patched CR. Exiting."
      rm -f "$temp_file"
      log_fail
      exit 1
    fi
    log "Cleaning up temporary files..."
    rm -f "$temp_file"
    log "Patch applied successfully."
  
  fi
}

# generate_argocd_api_token:: generates argoCD api key after logging in to the argocd server
generate_argocd_api_token() {
  local namespace="${1:-openshift-gitops}"

  log "Retrieving Argo CD creds..."
  get_argocd_admin_creds
  if ! argocd login "$ARGOCD_HOSTNAME" \
    --username admin \
    --password "$ARGOCD_PASSWORD" \
    --insecure \
    --skip-test-tls \
    --grpc-web >/dev/null 2>&1; then
    log "Login failed."
    log_fail
    return 1
  fi
  log "Generating API token for admin account..."
  ARGOCD_API_TOKEN=$(argocd account generate-token --account admin)
  if [[ -z "$ARGOCD_API_TOKEN" ]]; then
    log "Failed to generate API token."
    return 1
  fi
  export ARGOCD_API_TOKEN
  log "ARGOCD_API_TOKEN exported for this session."
}

# create_sa_tokens: creates rhdh & k8s sa and their tokens
create_sa_tokens() {
  local namespace="$1"

  kubectl create serviceaccount k8s-sa -n "$namespace" >/dev/null 2>&1 || log "'k8s-sa' already exists."
  kubectl create serviceaccount rhdh-sa -n "$namespace" >/dev/null 2>&1 || log "'rhdh-sa' already exists."
  kubectl create serviceaccount mcp-actions-sa -n "$namespace" >/dev/null 2>&1 || log "'mcp-actions-sa' already exists."
  log "Creating role binding for 'k8s-sa'..."
  kubectl create rolebinding k8s-admin-binding \
    --clusterrole=admin \
    --serviceaccount="$namespace:k8s-sa" \
    --namespace="$namespace" >/dev/null 2>&1 || log "Role binding already exists."
  kubectl create rolebinding k8s-reader-binding \
    --clusterrole=cluster-reader \
    --serviceaccount="$namespace:k8s-sa" \
    --namespace="$namespace" >/dev/null 2>&1 || log "Role binding already exists."
  log "Creating token for 'k8s-sa' (1 year)..."
  K8S_CLUSTER_TOKEN=$(kubectl create token k8s-sa -n "$namespace" --duration 8760h 2>/dev/null)
  log "Creating token for 'rhdh-sa'..."
  RHDH_SA_TOKEN=$(kubectl create token rhdh-sa -n "$namespace" 2>/dev/null)
  log "Creating token for 'mcp-actions-sa'..."
  MCP_TOKEN=$(kubectl create token mcp-actions-sa -n "$namespace" 2>/dev/null)
  export K8S_CLUSTER_TOKEN
  export RHDH_SA_TOKEN
  export MCP_TOKEN
  log "Service accounts and tokens created."
}

# get_argocd_admin_creds: fetches argocd admin password and argocd hostname
get_argocd_admin_creds() {
  local namespace="${1:-openshift-gitops}"

  log "Getting Argo CD admin password and hostname from namespace '$namespace'..."
  ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster -n "$namespace" -o jsonpath='{.data.admin\.password}' | base64 -d)
  ARGOCD_HOSTNAME=$(oc get route openshift-gitops-server -n "$namespace" -o jsonpath='{.status.ingress[0].host}')
  if [[ -z "$ARGOCD_PASSWORD" || -z "$ARGOCD_HOSTNAME" ]]; then
    log "Failed to retrieve Argo CD credentials. Exiting."
    return 1
  fi
  export ARGOCD_PASSWORD
  export ARGOCD_HOSTNAME
  log "Retrieved Argo CD admin credentials."
}

# configure_cosign_signing_secret: configures signing secret
configure_cosign_signing_secret() {
  local namespace="${1:-openshift-pipelines}"
  local random_pass

  random_pass=$(openssl rand -base64 30)
  log "Deleting existing 'signing-secrets' secret (if it exists)..."
  kubectl delete secret "signing-secrets" -n "$namespace" --ignore-not-found=true >/dev/null 2>&1
  log "Generating new Cosign key pair into 'signing-secrets'..."
  if ! env COSIGN_PASSWORD="$random_pass" cosign generate-key-pair "k8s://$namespace/signing-secrets" >/dev/null 2>&1; then
    log "Failed to generate cosign key pair. Exiting."
    log_fail
    return 1
  fi
  log "Marking 'signing-secrets' as immutable..."
  kubectl patch secret "signing-secrets" -n "$namespace" \
    --dry-run=client -o yaml \
    --patch='{"immutable": true}' 2>/dev/null \
    | kubectl apply -f - >/dev/null 2>&1
  log "Cosign signing secret configured and made immutable."
}

# ----------- Setup ENV ----------- #

source ./private-env

# ----------- main ----------- #

# Allow ArgoCD Admin to generate apiKey
log "Setting up ArgoCD apiKey..."
enable_argocd_admin_apiKey "$ARGOCD_NAMESPACE" "$ARGOCD_NAMESPACE"

# Export the ARGOCD_API_TOKEN
log "Generating the ARGOCD_API_TOKEN..."
generate_argocd_api_token "$ARGOCD_NAMESPACE"

# Create project RHDH and LightSpeed Projects if they do not exist
log "Creating new project for $RHDH_NAMESPACE..."
create_project "$RHDH_NAMESPACE"
log "Creating new project for $LIGHTSPEED_POSTGRES_NAMESPACE..."
create_project $LIGHTSPEED_POSTGRES_NAMESPACE
log "Labeling $LIGHTSPEED_POSTGRES_NAMESPACE for ArgoCD management..."
add_argocd_label "$LIGHTSPEED_POSTGRES_NAMESPACE"

# Create the necessary ServiceAccount token
log "Creating k8s and RHDH SA tokens..."
create_sa_tokens "$RHDH_NAMESPACE"

# ----------- Secrets Setup ----------- #

log "Setting up secrets on $RHDH_NAMESPACE and $PAC_NAMESPACE"

SECRET_NAME="github-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=GITHUB_ORG="$GITHUB_ORG" \
    --from-literal=GITHUB_APP_APP_ID="$GITHUB_APP_APP_ID" \
    --from-literal=GITHUB_APP_CLIENT_ID="$GITHUB_APP_CLIENT_ID" \
    --from-literal=GITHUB_APP_CLIENT_SECRET="$GITHUB_APP_CLIENT_SECRET" \
    --from-literal=GITHUB_APP_WEBHOOK_URL="$GITHUB_APP_WEBHOOK_URL" \
    --from-literal=GITHUB_APP_WEBHOOK_SECRET="$GITHUB_APP_WEBHOOK_SECRET" \
    --from-literal=GITHUB_APP_PRIVATE_KEY="$GITHUB_APP_PRIVATE_KEY" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="lightspeed-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=OLLAMA_URL="$OLLAMA_URL" \
    --from-literal=OLLAMA_TOKEN="$OLLAMA_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="llama-stack-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=VLLM_URL="$VLLM_URL" \
    --from-literal=VLLM_API_KEY="$VLLM_API_KEY" \
    --from-literal=VALIDATION_PROVIDER="$VALIDATION_PROVIDER" \
    --from-literal=VALIDATION_MODEL_NAME="$VALIDATION_MODEL_NAME" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="kubernetes-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=K8S_CLUSTER_TOKEN="$K8S_CLUSTER_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="rolling-demo-postgresql"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=postgres-password="$POSTGRESQL_POSTGRES_PASSWORD" \
    --from-literal=password="$POSTGRESQL_USER_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="quay-pull-secret"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=.dockerconfigjson="$QUAY_DOCKERCONFIGJSON" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="keycloak-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=KEYCLOAK_METADATA_URL="$KEYCLOAK_METADATA_URL" \
    --from-literal=KEYCLOAK_CLIENT_ID="$KEYCLOAK_CLIENT_ID" \
    --from-literal=KEYCLOAK_REALM="$KEYCLOAK_REALM" \
    --from-literal=KEYCLOAK_BASE_URL="$KEYCLOAK_BASE_URL" \
    --from-literal=KEYCLOAK_LOGIN_REALM="$KEYCLOAK_LOGIN_REALM" \
    --from-literal=KEYCLOAK_CLIENT_SECRET="$KEYCLOAK_CLIENT_SECRET" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="rhdh-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=BACKEND_SECRET="$BACKEND_SECRET" \
    --from-literal=ADMIN_TOKEN="$RHDH_SA_TOKEN" \
    --from-literal=MCP_TOKEN="$MCP_TOKEN" \
    --from-literal=RHDH_BASE_URL="$RHDH_BASE_URL" \
    --from-literal=RHDH_CALLBACK_URL="$RHDH_CALLBACK_URL" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="ai-rh-developer-hub-env"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=NODE_TLS_REJECT_UNAUTHORIZED="0" \
    --from-literal=RHDH_TOKEN="$RHDH_SA_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="argocd-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=ARGOCD_USER="$ARGOCD_USER" \
    --from-literal=ARGOCD_PASSWORD="$ARGOCD_PASSWORD" \
    --from-literal=ARGOCD_HOSTNAME="$ARGOCD_HOSTNAME" \
    --from-literal=ARGOCD_API_TOKEN="$ARGOCD_API_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="pipelines-as-code-secret"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$PAC_NAMESPACE" \
    --from-literal=github-application-id="$GITHUB_APP_APP_ID" \
    --from-literal=github-private-key="$GITHUB_APP_PRIVATE_KEY" \
    --from-literal=webhook.secret="$GITHUB_APP_WEBHOOK_SECRET" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="lightspeed-postgres-info"
log "Creating $SECRET_NAME secret in $LIGHTSPEED_POSTGRES_NAMESPACE..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=user="$LIGHTSPEED_POSTGRES_USER" \
    --from-literal=password="$LIGHTSPEED_POSTGRES_PASSWORD" \
    --from-literal=db-name="$LIGHTSPEED_POSTGRES_DB" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="lightspeed-postgres-info"
log "Creating $SECRET_NAME secret in $RHDH_NAMESPACE..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=namespace="$LIGHTSPEED_POSTGRES_NAMESPACE" \
    --from-literal=user="$LIGHTSPEED_POSTGRES_USER" \
    --from-literal=password="$LIGHTSPEED_POSTGRES_PASSWORD" \
    --from-literal=db-name="$LIGHTSPEED_POSTGRES_DB" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

# ------------- Setup Openshift Pipelines ------------- #

# Configure cosign
log "Configuring Cosign signing secrets in namespace '$PAC_NAMESPACE'..."
configure_cosign_signing_secret "$PAC_NAMESPACE"

# Configure the pipelines setup - see scripts/configure-pipelines for more details
bash ./configure-pipelines.sh
log "Tekton Pipelines configured successfully"