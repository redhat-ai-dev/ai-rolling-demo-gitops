#!/bin/bash

# SCRIPTS_DIR: the scripts/ subdirectory relative to this file
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"

source "$SCRIPTS_DIR/common.sh"

source "$SCRIPTS_DIR/private-env"

# Recompute URL vars using the actual route name: {{ .Release.Name }}-backstage
# The release name equals ARGOCD_APP_NAME, so both namespace and app name affect the URL.
RHDH_BASE_URL="https://${ARGOCD_APP_NAME}-backstage-${RHDH_NAMESPACE}.${RHDH_CLUSTER_ROUTER_BASE}"
RHDH_CALLBACK_URL="${RHDH_BASE_URL}/api/auth/oidc/handler/frame"
export RHDH_BASE_URL RHDH_CALLBACK_URL

# check_tools: verifies that all required CLI tools are installed
check_tools() {
  local missing=()
  local tools=("oc" "kubectl" "yq" "argocd" "cosign" "openssl" "envsubst")

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log "'$tool' is not installed or not in PATH."
      missing+=("$tool")
    else
      log "'$tool' is installed."
    fi
  done
  if (( ${#missing[@]} )); then
    log "Missing required tools: ${missing[*]}"
    log_fail
    exit 1
  fi
}

log "Setting Up Rolling Demo Environment..."
log "Checking if all required tools are installed..."
check_tools

# Validate required env vars
required_vars=(
  GITOPS_REPO_URL
  GITOPS_TARGET_REVISION
  RHDH_CLUSTER_ROUTER_BASE
  GITOPS_GIT_ORG
  GITHUB_APP_APP_ID
  GITHUB_APP_CLIENT_ID
  GITHUB_APP_CLIENT_SECRET
  GITHUB_APP_WEBHOOK_URL
  GITHUB_APP_WEBHOOK_SECRET
  GITHUB_APP_PRIVATE_KEY
  ARGOCD_USER
  BACKEND_SECRET
  RHDH_CALLBACK_URL
  POSTGRESQL_POSTGRES_PASSWORD
  POSTGRESQL_USER_PASSWORD
  QUAY_DOCKERCONFIGJSON
  KEYCLOAK_METADATA_URL
  KEYCLOAK_CLIENT_ID
  KEYCLOAK_REALM
  KEYCLOAK_BASE_URL
  KEYCLOAK_LOGIN_REALM
  KEYCLOAK_CLIENT_SECRET
  VLLM_URL
  VLLM_API_KEY
  VALIDATION_PROVIDER
  VALIDATION_MODEL_NAME
)
if [[ "${SKIP_RHOAI_SETUP}" != "true" ]]; then
  required_vars+=(ODH_SETUP_DIR)
fi
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    log "Error: $var is not set. Exiting..."
    log_fail
    exit 1
  fi
done

# skip operators and RHOAI installation if that's the case
if [[ "${SKIP_INSTALL_DEPS}" == "true" ]]; then
  log "SKIP_INSTALL_DEPS=true — skipping operator/instance installation."
else
  bash "$SCRIPTS_DIR/install-operators.sh"
fi
if [[ "${SKIP_RHOAI_SETUP}" == "true" ]]; then
  log "SKIP_RHOAI_SETUP=true — skipping ODH Kubeflow Model Registry setup."
else
  bash "$SCRIPTS_DIR/setup-rhoai.sh"
fi

# source other setup scripts to create namespaces, service accounts, secrets, and ArgoCD setup
source "$SCRIPTS_DIR/setup-argocd.sh"
source "$SCRIPTS_DIR/setup-namespaces.sh"
source "$SCRIPTS_DIR/setup-sa-tokens.sh"
source "$SCRIPTS_DIR/setup-secrets.sh"

# finally apply ArgoCD applications to deploy the demo components
bash "$SCRIPTS_DIR/setup-pipelines.sh"
bash "$SCRIPTS_DIR/apply-argocd-application.sh"

log "Rolling Demo Setup Completed Successfully!"
