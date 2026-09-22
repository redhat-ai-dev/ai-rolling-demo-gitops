#!/usr/bin/env bash
# Live-cluster check: Backstage Deployment containers must not include legacy
# KServe/OpenShift AI connector sidecars.
#
# Usage:
#   tests/fixtures/kserve/assert-no-connector-sidecars.sh [namespace] [deployment-name]
#
# Defaults: namespace=rhdhai-development, deployment auto-detected as the first
# Deployment that has a container named backstage-backend (or backstage).

set -euo pipefail

NAMESPACE="${1:-rhdhai-development}"
DEPLOYMENT="${2:-}"

LEGACY=(
  storage-rest
  rhoai-normalizer
  model-catalog-location-service
  location
)

if [[ -z "$DEPLOYMENT" ]]; then
  DEPLOYMENT="$(
    kubectl get deploy -n "$NAMESPACE" -o json \
      | jq -r '
          .items[]
          | select(
              any(.spec.template.spec.containers[]?;
                  .name == "backstage-backend" or .name == "backstage")
            )
          | .metadata.name
        ' \
      | head -n1
  )"
fi

if [[ -z "$DEPLOYMENT" ]]; then
  echo "ERROR: could not find a Backstage Deployment in namespace ${NAMESPACE}" >&2
  exit 1
fi

NAMES="$(
  kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o json \
    | jq -r '.spec.template.spec.containers[].name'
)"

echo "Checking containers on ${NAMESPACE}/${DEPLOYMENT}:"
echo "$NAMES" | sed 's/^/  - /'

FOUND=0
while IFS= read -r name; do
  for legacy in "${LEGACY[@]}"; do
    # Exact name match only — avoid false positives on unrelated "location" strings.
    if [[ "$name" == "$legacy" ]]; then
      echo "FAIL: legacy connector sidecar container present: ${name}" >&2
      FOUND=1
    fi
  done
done <<< "$NAMES"

if [[ "$FOUND" -ne 0 ]]; then
  exit 1
fi

echo "PASS: no legacy connector sidecar containers on ${NAMESPACE}/${DEPLOYMENT}"
