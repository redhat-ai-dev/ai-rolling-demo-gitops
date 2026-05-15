#!/bin/bash
set -euo pipefail

# SCRIPTS_DIR: the directory containing this script.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GITOPS_DIR: the root of the repository.
GITOPS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# source common functions and variables
source "$SCRIPTS_DIR/common.sh"

# Source private-env if it exists (local dev); in CI env vars come from the workflow.
if [ -f "$SCRIPTS_DIR/private-env" ]; then
  # shellcheck source=/dev/null
  source "$SCRIPTS_DIR/private-env"
fi

# CI_HOSTNAME: a consistent hostname for CI, but allow override
# for flexibility in local testing
CI_HOSTNAME="${CI_HOSTNAME:-rhdh-ci.apps.testing}"
export RHDH_BASE_URL="https://$CI_HOSTNAME"
export RHDH_CALLBACK_URL="$RHDH_BASE_URL/api/auth/oidc/handler/frame"

# auto-generate secrets not provided externally
export BACKEND_SECRET="${BACKEND_SECRET:-$(openssl rand -hex 32)}"
export POSTGRESQL_POSTGRES_PASSWORD="${POSTGRESQL_POSTGRES_PASSWORD:-$(openssl rand -hex 16)}"
export POSTGRESQL_USER_PASSWORD="${POSTGRESQL_USER_PASSWORD:-$(openssl rand -hex 16)}"

# use stub values for GitHub App integration which is not tested in CI
export GITOPS_GIT_ORG="${GITOPS_GIT_ORG:-ci-placeholder}"
export GITHUB_APP_APP_ID="${GH_APP_APP_ID:-${GITHUB_APP_APP_ID:-0}}"
export GITHUB_APP_CLIENT_ID="${GH_APP_CLIENT_ID:-${GITHUB_APP_CLIENT_ID:-ci-placeholder}}"
export GITHUB_APP_CLIENT_SECRET="${GH_APP_CLIENT_SECRET:-${GITHUB_APP_CLIENT_SECRET:-ci-placeholder}}"
export GITHUB_APP_WEBHOOK_URL="${GH_APP_WEBHOOK_URL:-${GITHUB_APP_WEBHOOK_URL:-http://ci-placeholder}}"
export GITHUB_APP_WEBHOOK_SECRET="${GH_APP_WEBHOOK_SECRET:-${GITHUB_APP_WEBHOOK_SECRET:-ci-placeholder}}"
export GITHUB_APP_PRIVATE_KEY="${GH_APP_PRIVATE_KEY:-${GITHUB_APP_PRIVATE_KEY:-ci-placeholder}}"

# use stub values for services not deployed in CI
export OLLAMA_URL="${OLLAMA_URL:-}"
export OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
export ARGOCD_USER="${ARGOCD_USER:-admin}"
export ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-$(openssl rand -base64 16)}"
export ARGOCD_HOSTNAME="${ARGOCD_HOSTNAME:-}"
export ARGOCD_API_TOKEN="${ARGOCD_API_TOKEN:-}"

# setup lightspeed required secret values
export ENABLE_VLLM="true"
export VLLM_URL="${VLLM_URL:?VLLM_URL must be set}"
export VLLM_API_KEY="${VLLM_API_KEY:?VLLM_API_KEY must be set}"
export VALIDATION_PROVIDER="${VALIDATION_PROVIDER:?VALIDATION_PROVIDER must be set}"
export VALIDATION_MODEL_NAME="${VALIDATION_MODEL_NAME:?VALIDATION_MODEL_NAME must be set}"
export LIGHTSPEED_POSTGRES_USER="${LIGHTSPEED_POSTGRES_USER:?LIGHTSPEED_POSTGRES_USER must be set}"
export LIGHTSPEED_POSTGRES_PASSWORD="${LIGHTSPEED_POSTGRES_PASSWORD:?LIGHTSPEED_POSTGRES_PASSWORD must be set}"
export LIGHTSPEED_POSTGRES_DB="${LIGHTSPEED_POSTGRES_DB:?LIGHTSPEED_POSTGRES_DB must be set}"
export NOTEBOOKS_QUERY_PROVIDER_ID="${NOTEBOOKS_QUERY_PROVIDER_ID:?NOTEBOOKS_QUERY_PROVIDER_ID must be set}"
export NOTEBOOKS_QUERY_MODEL="${NOTEBOOKS_QUERY_MODEL:?NOTEBOOKS_QUERY_MODEL must be set}"

# we consider this to be a secondary instance. This will skip pipelines-as-code-secret
# and lightspeed-postgres-info secrets, since their namespaces do not exist on kind
export IS_SECONDARY_INSTANCE="true"

# create the kind cluster
log "Creating Kind cluster..."
kind create cluster --config "$GITOPS_DIR/ci/kind-config.yaml" --name rhdh-ci
kubectl cluster-info --context kind-rhdh-ci

# create the ingress-nginx controller
log "Installing nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml
log "Waiting for ingress-nginx controller pod to be created..."
until kubectl get pods --namespace ingress-nginx \
  --selector=app.kubernetes.io/component=controller \
  --no-headers 2>/dev/null | grep -q .; do
  sleep 2
done
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
log "Adding $CI_HOSTNAME to /etc/hosts..."
echo "127.0.0.1 $CI_HOSTNAME" | sudo tee -a /etc/hosts

# create namespaces for RHDH
source "$SCRIPTS_DIR/setup-namespaces.sh"

# cluster-reader won't exist on kind, we need to create it
# so rolling-demo-rbac.yaml ClusterRoleBinding won't fail.
log "Creating cluster-reader ClusterRole..."
kubectl create clusterrole cluster-reader \
  --verb=get,list,watch \
  --resource='*' 2>/dev/null || log "cluster-reader already exists."

# create service accounts and tokens for RHDH components
source "$SCRIPTS_DIR/setup-sa-tokens.sh"

# run the secrets generation script
# we have already prepared all necessary env vars
source "$SCRIPTS_DIR/setup-secrets.sh"

# initial installation of rhdh-chart provided our ci values
log "Installing RHDH chart via Helm..."
helm install "$ARGOCD_APP_NAME" "$GITOPS_DIR/charts/rhdh" \
  --namespace "$RHDH_NAMESPACE" \
  -f "$GITOPS_DIR/charts/rhdh/values.yaml" \
  -f "$GITOPS_DIR/ci/values-ci.yaml" \
  --set 'global.dynamic.plugins[8].disabled=true' \
  --set 'global.dynamic.plugins[9].disabled=true' \
  --timeout 20m \
  --wait

# generate a self-signed TLS certificate so node-openid-client accepts the HTTPS callback URL
log "Generating self-signed TLS certificate for $CI_HOSTNAME..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/ci-tls.key \
  -out /tmp/ci-tls.crt \
  -subj "/CN=$CI_HOSTNAME" \
  -addext "subjectAltName=DNS:$CI_HOSTNAME" \
  2>/dev/null
kubectl create secret tls rhdh-tls \
  --cert=/tmp/ci-tls.crt \
  --key=/tmp/ci-tls.key \
  --namespace "$RHDH_NAMESPACE"

# ingress component for backstage using the CI_HOSTNAME value
log "Creating Ingress for RHDH..."
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rhdh-ingress
  namespace: $RHDH_NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - $CI_HOSTNAME
      secretName: rhdh-tls
  rules:
    - host: $CI_HOSTNAME
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${ARGOCD_APP_NAME}-backstage
                port:
                  number: 7007
EOF

log "Waiting for RHDH to be ready..."
kubectl rollout status deployment/"${ARGOCD_APP_NAME}-backstage" \
  -n "$RHDH_NAMESPACE" --timeout=300s

# Kind limited resources (better not to install Argo): render the job
# template with global.ci=false to override values-ci.yaml, then apply
# it directly. This will by-pass the postsync hook of ArgoCD and add
# all sidecars through a normal job.
log "Applying sidecars job..."
helm template "$ARGOCD_APP_NAME" "$GITOPS_DIR/charts/rhdh" \
  --namespace "$RHDH_NAMESPACE" \
  -f "$GITOPS_DIR/charts/rhdh/values.yaml" \
  -f "$GITOPS_DIR/ci/values-ci.yaml" \
  --set global.ci=false \
  -s templates/rolling-demo-sidecars-job.yaml \
  | kubectl apply -n "$RHDH_NAMESPACE" -f -

log "Waiting for sidecars job to complete..."
kubectl wait job/update-deployment-containers \
  -n "$RHDH_NAMESPACE" \
  --for=condition=complete \
  --timeout=600s

log "Waiting for RHDH to be ready after sidecars patch..."
kubectl rollout status deployment/"${ARGOCD_APP_NAME}-backstage" \
  -n "$RHDH_NAMESPACE" --timeout=300s

log "CI setup complete. RHDH is available at http://$CI_HOSTNAME"
