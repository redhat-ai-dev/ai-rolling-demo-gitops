#!/usr/bin/env bash
# Install upstream KServe on Kind in RawDeployment mode (no Knative / no RHOAI).
#
# Used by Kind CI so Playwright can exercise live InferenceService → AiModelServerAPI
# ingestion instead of soft-skipping behind KSERVE_E2E (RHIDP-17561 / follow-up to #339).
#
# Scope: InferenceService only. LLMInferenceService is intentionally out of scope.
#
# Aligns with Gabe Montero's Kind KServe recipe direction:
#   https://docs.google.com/document/d/1tKtfZjmgVfwxvxKJuJhwwqOnYrj2XAPgVT5pYHq9wKQ/edit
# Lean path: cert-manager + KServe CRDs/controller with RawDeployment (matches
# tests/fixtures/kserve/kind-*.yaml). Istio/Knative are skipped to fit Kind CI resources.
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/common.sh"

KSERVE_VERSION="${KSERVE_VERSION:-v0.15.2}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.1}"

if ! command -v helm >/dev/null 2>&1; then
  log_fail "helm is required to install KServe on Kind."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  log_fail "kubectl is required to install KServe on Kind."
  exit 1
fi

if kubectl get deployment kserve-controller-manager -n kserve >/dev/null 2>&1; then
  log "KServe controller already present in namespace kserve — skipping install."
  kubectl wait --namespace kserve \
    --for=condition=Available deployment/kserve-controller-manager \
    --timeout=300s
  exit 0
fi

log "Installing cert-manager ${CERT_MANAGER_VERSION} (KServe webhook dependency)..."
kubectl apply -f \
  "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
kubectl wait --namespace cert-manager \
  --for=condition=Available deployment \
  --all \
  --timeout=300s

log "Installing KServe CRDs ${KSERVE_VERSION}..."
helm upgrade --install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd \
  --version "${KSERVE_VERSION}" \
  --namespace kserve \
  --create-namespace \
  --wait \
  --timeout 10m

log "Installing KServe controller ${KSERVE_VERSION} (RawDeployment)..."
helm upgrade --install kserve oci://ghcr.io/kserve/charts/kserve \
  --version "${KSERVE_VERSION}" \
  --namespace kserve \
  --create-namespace \
  --wait \
  --timeout 10m \
  --set-string kserve.controller.deploymentMode=RawDeployment

kubectl wait --namespace kserve \
  --for=condition=Available deployment/kserve-controller-manager \
  --timeout=300s

log "KServe RawDeployment install complete (${KSERVE_VERSION})."
log "Apply fixtures with: tests/fixtures/kserve/apply.sh kind <namespace>"
