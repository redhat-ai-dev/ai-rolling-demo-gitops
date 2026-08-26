#!/bin/bash
log "Setting up secrets on $RHDH_NAMESPACE and $PAC_NAMESPACE"

SECRET_NAME="github-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=GITOPS_GIT_ORG="$GITOPS_GIT_ORG" \
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
    --from-literal=ENABLE_VLLM="true" \
    --from-literal=ENABLE_VALIDATION="${ENABLE_VALIDATION:-question_validity}" \
    --from-literal=VLLM_URL="$VLLM_URL" \
    --from-literal=VLLM_API_KEY="$VLLM_API_KEY" \
    --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY:-passthrough}" \
    --from-literal=VALIDATION_PROVIDER="$VALIDATION_PROVIDER" \
    --from-literal=VALIDATION_MODEL_NAME="$VALIDATION_MODEL_NAME" \
    --from-literal=NOTEBOOKS_QUERY_PROVIDER_ID="$NOTEBOOKS_QUERY_PROVIDER_ID" \
    --from-literal=NOTEBOOKS_QUERY_MODEL="$NOTEBOOKS_QUERY_MODEL" \
    --from-literal=PGVECTOR_DB="$LIGHTSPEED_POSTGRES_DB" \
    --from-literal=PGVECTOR_USER="$LIGHTSPEED_POSTGRES_USER" \
    --from-literal=PGVECTOR_PASSWORD="$LIGHTSPEED_POSTGRES_PASSWORD" \
    --from-literal=VERTEX_AI_PROJECT="${VERTEX_AI_PROJECT:-passthrough}" \
    --from-literal=VERTEX_AI_LOCATION="${VERTEX_AI_LOCATION:-global}" \
    --from-literal=VERTEX_AI_CREDENTIALS="${VERTEX_AI_CREDENTIALS:-}" \
    --from-literal=OTEL_SDK_DISABLED="${OTEL_SDK_DISABLED:-true}" \
    --from-literal=KV_STORE_PATH="${KV_STORE_PATH:-/tmp/kvstore.db}" \
    --from-literal=SQL_STORE_PATH="${SQL_STORE_PATH:-/tmp/sql_store.db}" \
    --from-literal=SQLITE_STORE_DIR="${SQLITE_STORE_DIR:-/tmp/llama-stack-files}" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="kubernetes-secrets"
log "Creating $SECRET_NAME secret..."
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=K8S_CLUSTER_TOKEN="$K8S_CLUSTER_TOKEN" \
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
log "Secret $SECRET_NAME created successfully."

SECRET_NAME="${ARGOCD_APP_NAME}-postgresql"
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

SECRET_NAME="kserve-connector-secrets"
log "Creating $SECRET_NAME secret..."
KSERVE_CLUSTER_URL="${K8S_CLUSTER_URL:-}"
KSERVE_SA_TOKEN="${K8S_SA_TOKEN:-}"
KSERVE_CA_DATA="${K8S_CA_DATA:-}"
KSERVE_MODEL_CATALOG_URL="${KUBEFLOW_MODEL_CATALOG_URL:-}"
if [[ "${SKIP_RHOAI_SETUP:-}" != "true" || "${RHOAI_PREINSTALLED:-}" == "true" ]]; then
  if [[ -z "$KSERVE_CLUSTER_URL" ]]; then
    KSERVE_CLUSTER_URL="https://kubernetes.default.svc"
    log "Using in-cluster API URL: $KSERVE_CLUSTER_URL"
  fi
  if [[ -z "$KSERVE_SA_TOKEN" ]]; then
    BRIDGE_TOKEN_DATA=$(kubectl get secret rhdh-rhoai-bridge-token -n "$RHDH_NAMESPACE" -o json 2>/dev/null || true)
    if [[ -n "$BRIDGE_TOKEN_DATA" ]]; then
      KSERVE_SA_TOKEN=$(echo "$BRIDGE_TOKEN_DATA" | jq -r '.data.token // empty' | base64 -d 2>/dev/null || true)
      if [[ -z "$KSERVE_CA_DATA" ]]; then
        KSERVE_CA_DATA=$(echo "$BRIDGE_TOKEN_DATA" | jq -r '.data["ca.crt"] // empty' 2>/dev/null || true)
      fi
      if [[ -n "$KSERVE_SA_TOKEN" ]]; then
        log "Auto-resolved K8S_SA_TOKEN from rhdh-rhoai-bridge-token secret."
      fi
    fi
  fi
  if [[ -z "$KSERVE_MODEL_CATALOG_URL" ]]; then
    KSERVE_MODEL_CATALOG_URL=$(kubectl get route -n rhoai-model-registries -o jsonpath='{.items[0].spec.host}' 2>/dev/null || true)
    if [[ -n "$KSERVE_MODEL_CATALOG_URL" ]]; then
      KSERVE_MODEL_CATALOG_URL="https://${KSERVE_MODEL_CATALOG_URL}"
      log "Auto-resolved KUBEFLOW_MODEL_CATALOG_URL from rhoai-model-registries route: $KSERVE_MODEL_CATALOG_URL"
    else
      KSERVE_MODEL_CATALOG_URL=$(kubectl get svc -n rhoai-model-registries -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
      if [[ -n "$KSERVE_MODEL_CATALOG_URL" ]]; then
        KSERVE_MODEL_CATALOG_URL="http://${KSERVE_MODEL_CATALOG_URL}.rhoai-model-registries.svc:8080"
        log "Auto-resolved KUBEFLOW_MODEL_CATALOG_URL from rhoai-model-registries service: $KSERVE_MODEL_CATALOG_URL"
      else
        log "Warning: Could not auto-resolve KUBEFLOW_MODEL_CATALOG_URL. Set it in private-env if model catalog features are needed."
      fi
    fi
  fi
fi
kubectl create secret generic "$SECRET_NAME" \
    --namespace="$RHDH_NAMESPACE" \
    --from-literal=K8S_CLUSTER_URL="${KSERVE_CLUSTER_URL}" \
    --from-literal=K8S_SA_TOKEN="${KSERVE_SA_TOKEN}" \
    --from-literal=K8S_CA_DATA="${KSERVE_CA_DATA}" \
    --from-literal=KUBEFLOW_MODEL_CATALOG_URL="${KSERVE_MODEL_CATALOG_URL}" \
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

# only create pipeline-as-code-secret and lightspeed-postgres-info secrets if
# this is not a secondary instance, as they are only needed for the initial RHDH
# instance in the cluster, and not for any additional RHDH instances we might want
# to deploy in the same cluster
if [[ "${IS_SECONDARY_INSTANCE}" != "true" ]]; then
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
      --from-literal=dev-db-name="${LIGHTSPEED_POSTGRES_DEV_DB:-}" \
      --from-literal=dev-user="${LIGHTSPEED_POSTGRES_DEV_USER:-}" \
      --from-literal=dev-password="${LIGHTSPEED_POSTGRES_DEV_PASSWORD:-}" \
      --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
  log "Secret $SECRET_NAME created successfully."
fi

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
