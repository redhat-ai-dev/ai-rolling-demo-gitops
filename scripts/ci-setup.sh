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
export ARGOCD_USER="${ARGOCD_USER:-dummy-argocd-user}"
export ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-dummy-argocd-password}"
export ARGOCD_HOSTNAME="${ARGOCD_HOSTNAME:-dummy-argocd-hostname}"
export ARGOCD_API_TOKEN="${ARGOCD_API_TOKEN:-dummy-argocd-token}"

# setup lightspeed required secret values
if [ -z "${OPENAI_API_KEY:-}" ] || [ -z "${VLLM_URL:-}" ] || [ -z "${VLLM_API_KEY:-}" ] || \
   [ -z "${LIGHTSPEED_POSTGRES_USER:-}" ] || [ -z "${LIGHTSPEED_POSTGRES_PASSWORD:-}" ] || \
   [ -z "${LIGHTSPEED_POSTGRES_DB:-}" ]; then
  echo "WARNING: Required secrets are not set. If you are working from a fork, push your branch to the upstream repo and re-open the PR from there. For local runs, see docs/TESTING.md." >&2
fi
# New LCORE images require OTEL_ANONYMIZATION_SECRET when OTEL is enabled (RAG path).
# Disable the SDK in CI instead of provisioning that secret.
export OTEL_SDK_DISABLED=true
export KV_STORE_PATH="/tmp/kvstore.db"
export SQL_STORE_PATH="/tmp/sql_store.db"
export SQLITE_STORE_DIR="/tmp/llama-stack-files"
export ENABLE_VALIDATION=__disabled__
export ENABLE_VLLM="true"
export ENABLE_OPENAI="true"
export OPENAI_API_KEY="${OPENAI_API_KEY:?OPENAI_API_KEY must be set}"
export VLLM_URL="${VLLM_URL:?VLLM_URL must be set}"
export VLLM_API_KEY="${VLLM_API_KEY:?VLLM_API_KEY must be set}"
# CI uses OpenAI while the shared vLLM test endpoint is unstable.
export VALIDATION_PROVIDER="${VALIDATION_PROVIDER:-openai}"
export VALIDATION_MODEL_NAME="${VALIDATION_MODEL_NAME:-gpt-4o-mini}"
export LIGHTSPEED_POSTGRES_USER="${LIGHTSPEED_POSTGRES_USER:?LIGHTSPEED_POSTGRES_USER must be set}"
export LIGHTSPEED_POSTGRES_PASSWORD="${LIGHTSPEED_POSTGRES_PASSWORD:?LIGHTSPEED_POSTGRES_PASSWORD must be set}"
export LIGHTSPEED_POSTGRES_DB="${LIGHTSPEED_POSTGRES_DB:?LIGHTSPEED_POSTGRES_DB must be set}"
export NOTEBOOKS_QUERY_PROVIDER_ID="${NOTEBOOKS_QUERY_PROVIDER_ID:-openai}"
export NOTEBOOKS_QUERY_MODEL="${NOTEBOOKS_QUERY_MODEL:-gpt-4o-mini}"

# we consider this to be a secondary instance. This will skip pipelines-as-code-secret
# and lightspeed-postgres-info secrets, since their namespaces do not exist on kind
export IS_SECONDARY_INSTANCE="true"

# Install upstream KServe (RawDeployment) + apply InferenceService fixtures so
# Kind CI can run the KServe connector cluster-fixture Playwright cases
# (RHIDP-17561). Set INSTALL_KSERVE_KIND=false to skip.
export INSTALL_KSERVE_KIND="${INSTALL_KSERVE_KIND:-true}"
export KSERVE_FIXTURE_NAMESPACE="${KSERVE_FIXTURE_NAMESPACE:-ggmtest}"

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
  --timeout=240s
log "Adding $CI_HOSTNAME to /etc/hosts..."
echo "127.0.0.1 $CI_HOSTNAME" | sudo tee -a /etc/hosts

if [[ "${INSTALL_KSERVE_KIND}" == "true" ]]; then
  log "Installing upstream KServe (RawDeployment) on Kind..."
  bash "$SCRIPTS_DIR/install-kserve-kind.sh"
fi

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

# Notebooks use the inline faiss vector store (on-disk at /tmp), so CI does not
# deploy a pgvector Postgres instance.

# Strip OKP config from lightspeed-stack so LCORE starts without OKP on Kind.
# The file is a Helm ConfigMap template ({{ .Release.Namespace }}), so yq can't
# parse it — use sed instead. Removes "- okp" from rag.retrieval.tool.sources
# and the nested rag.okp block.
log "Stripping OKP config from lightspeed-stack-config for CI..."
sed -i.bak '/^[[:space:]]*- okp$/d' \
  "$GITOPS_DIR/charts/rhdh/templates/lightspeed-stack-config.yaml"
sed -i.bak '/^      okp:$/,/^      [^ ]/{ /^      [^ ]/!d; /^      okp:$/d; }' \
  "$GITOPS_DIR/charts/rhdh/templates/lightspeed-stack-config.yaml"
rm -f "$GITOPS_DIR/charts/rhdh/templates/lightspeed-stack-config.yaml.bak"

# initial installation of rhdh-chart provided our ci values
log "Installing RHDH chart via Helm..."
# Disable the scaffolder MCP extras plugin for the Kind environment.
CI_RHDH_VALUES="$(mktemp)"
trap 'rm -f "$CI_RHDH_VALUES"' EXIT
yq '( ."redhat-developer-hub".dynamicPlugins.plugins[] | select(.package | contains("scaffolder-mcp-extras")) ).disabled = true' \
  "$GITOPS_DIR/charts/rhdh/values.yaml" > "$CI_RHDH_VALUES"
helm install "$ARGOCD_APP_NAME" "$GITOPS_DIR/charts/rhdh" \
  --namespace "$RHDH_NAMESPACE" \
  -f "$CI_RHDH_VALUES" \
  -f "$GITOPS_DIR/ci/values-ci.yaml" \
  --timeout 40m \
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
  -n "$RHDH_NAMESPACE" --timeout=600s

if [[ "${INSTALL_KSERVE_KIND}" == "true" ]]; then
  # Bridge token is Helm-managed; reconcile after install (same as setup.sh).
  log "Reconciling kserve-connector-secrets from rhdh-rhoai-bridge-token..."
  bash "$SCRIPTS_DIR/reconcile-kserve-secrets.sh"

  # Restart *before* applying InferenceService fixtures. Fixture predictors pull
  # model images and compete with RHDH for Kind memory; a post-fixture restart
  # previously timed out with old replicas stuck pending termination.
  log "Restarting RHDH so connector picks up reconciled cluster credentials..."
  kubectl rollout restart deployment/"${ARGOCD_APP_NAME}-backstage" \
    -n "$RHDH_NAMESPACE"
  if ! kubectl rollout status deployment/"${ARGOCD_APP_NAME}-backstage" \
    -n "$RHDH_NAMESPACE" --timeout=900s; then
    log "RHDH rollout after secret reconcile failed — collecting diagnostics..."
    kubectl get pods -n "$RHDH_NAMESPACE" -o wide || true
    kubectl describe deployment/"${ARGOCD_APP_NAME}-backstage" -n "$RHDH_NAMESPACE" || true
    kubectl get events -n "$RHDH_NAMESPACE" --sort-by='.lastTimestamp' | tail -40 || true
    exit 1
  fi

  log "Applying Kind KServe InferenceService fixtures in ${KSERVE_FIXTURE_NAMESPACE}..."
  bash "$GITOPS_DIR/tests/fixtures/kserve/apply.sh" kind "$KSERVE_FIXTURE_NAMESPACE"

  # Predictors already reported Ready; the connector only needs InferenceService
  # status fields. Scale them down so Playwright keeps Kind memory headroom.
  log "Scaling down fixture predictors to free Kind capacity..."
  kubectl -n "$KSERVE_FIXTURE_NAMESPACE" scale deploy --all --replicas=0 \
    2>/dev/null || true

  # Give ModelCatalogResourceEntityProvider a short window after IS Ready.
  log "Waiting for connector reconcile window after InferenceServices are Ready..."
  sleep 60
  export KSERVE_E2E=true
fi

log "CI setup complete. RHDH is available at http://$CI_HOSTNAME"
