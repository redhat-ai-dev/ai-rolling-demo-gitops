#!/usr/bin/env bash
# Apply KServe QE fixtures for the connector Playwright suite.
#
# Usage:
#   tests/fixtures/kserve/apply.sh rhoai [namespace]
#   tests/fixtures/kserve/apply.sh kind [namespace]
set -euo pipefail

TARGET="${1:-rhoai}"
NAMESPACE="${2:-ggmtest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$TARGET" != "rhoai" && "$TARGET" != "kind" ]]; then
  echo "Usage: $0 <rhoai|kind> [namespace]" >&2
  exit 1
fi

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

if [[ "$TARGET" == "rhoai" ]]; then
  kubectl apply -n "$NAMESPACE" -f "${SCRIPT_DIR}/mlserver-serving-runtime.yaml"
  kubectl apply -n "$NAMESPACE" -f "${SCRIPT_DIR}/inferenceservice.yaml"
  kubectl apply -n "$NAMESPACE" -f "${SCRIPT_DIR}/inferenceservice-overrides.yaml"
else
  kubectl apply -n "$NAMESPACE" -f "${SCRIPT_DIR}/kind-inferenceservice.yaml"
  kubectl apply -n "$NAMESPACE" -f "${SCRIPT_DIR}/kind-inferenceservice-overrides.yaml"
fi

echo "Waiting for InferenceServices in ${NAMESPACE} to become Ready..."
for name in sklearn-iris sklearn-iris-overrides; do
  kubectl wait --for=condition=Ready "inferenceservice/${name}" \
    -n "$NAMESPACE" \
    --timeout=600s
done

echo "Fixtures applied. An AiModelServerAPI entity is only ingested after the InferenceService reports status.url."
echo "Re-run Playwright with KSERVE_E2E=true once the connector reconciles (typically under a minute)."
