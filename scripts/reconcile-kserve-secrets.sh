#!/bin/bash

# Reconciles kserve-connector-secrets after ArgoCD has deployed the Helm chart.
# The rhdh-rhoai-bridge-token secret is Helm-managed and only exists after ArgoCD
# syncs, but setup-secrets.sh runs before the ArgoCD application is created.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/common.sh"

SECRET_NAME="kserve-connector-secrets"
BRIDGE_SECRET="rhdh-rhoai-bridge-token"
POLL_INTERVAL=15
TIMEOUT=300

EXISTING_TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$RHDH_NAMESPACE" \
  -o jsonpath='{.data.K8S_SA_TOKEN}' 2>/dev/null | base64 -d 2>/dev/null || true)
if [[ -n "$EXISTING_TOKEN" ]]; then
  log "K8S_SA_TOKEN in $SECRET_NAME is already populated. Skipping reconciliation."
  exit 0
fi

log "K8S_SA_TOKEN is empty in $SECRET_NAME. Waiting for $BRIDGE_SECRET to appear..."
elapsed=0
while (( elapsed < TIMEOUT )); do
  BRIDGE_TOKEN_DATA=$(kubectl get secret "$BRIDGE_SECRET" -n "$RHDH_NAMESPACE" -o json 2>/dev/null || true)
  if [[ -n "$BRIDGE_TOKEN_DATA" ]]; then
    SA_TOKEN=$(echo "$BRIDGE_TOKEN_DATA" | jq -r '.data.token // empty' | base64 -d 2>/dev/null || true)
    CA_DATA=$(echo "$BRIDGE_TOKEN_DATA" | jq -r '.data["ca.crt"] // empty' 2>/dev/null || true)
    if [[ -n "$SA_TOKEN" ]]; then
      log "Resolved K8S_SA_TOKEN from $BRIDGE_SECRET. Patching $SECRET_NAME..."
      CLUSTER_URL=$(kubectl get secret "$SECRET_NAME" -n "$RHDH_NAMESPACE" \
        -o jsonpath='{.data.K8S_CLUSTER_URL}' 2>/dev/null | base64 -d 2>/dev/null || true)
      CATALOG_URL=$(kubectl get secret "$SECRET_NAME" -n "$RHDH_NAMESPACE" \
        -o jsonpath='{.data.KUBEFLOW_MODEL_CATALOG_URL}' 2>/dev/null | base64 -d 2>/dev/null || true)
      kubectl create secret generic "$SECRET_NAME" \
        --namespace="$RHDH_NAMESPACE" \
        --from-literal=K8S_CLUSTER_URL="${CLUSTER_URL:-https://kubernetes.default.svc}" \
        --from-literal=K8S_SA_TOKEN="$SA_TOKEN" \
        --from-literal=K8S_CA_DATA="${CA_DATA}" \
        --from-literal=KUBEFLOW_MODEL_CATALOG_URL="$CATALOG_URL" \
        --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
      log "$SECRET_NAME reconciled successfully."
      log "Note: Restart the RHDH deployment if it started before this reconciliation."
      exit 0
    fi
  fi
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

log "Warning: Timed out waiting for $BRIDGE_SECRET. K8S_SA_TOKEN remains empty."
log "Set K8S_SA_TOKEN in private-env and re-run, or run this script again after ArgoCD sync completes."
exit 1
