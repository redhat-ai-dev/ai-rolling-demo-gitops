#!/usr/bin/env bash
# Assert the Helm chart installs the standalone KServe connector without
# legacy bridge sidecars (location / storage-rest / rhoai-normalizer).
#
# Mirrors RHIDP-14261 / RHIDP-17132 acceptance: Helm path must not reintroduce
# the old OpenShift AI connector sidecars, and must wire caData + connector config.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

LEGACY_SIDECARS=(
  storage-rest
  rhoai-normalizer
  model-catalog-location-service
  localhost:9090
)

helm template rolling-demo "${REPO_ROOT}/charts/rhdh" \
  --namespace rhdhai-development \
  --set okp.enabled=false \
  --set rhoai.enabled=true \
  --show-only templates/kserve-connector-config.yaml \
  > "${TEMP_DIR}/kserve-connector-config.yaml"

helm template rolling-demo "${REPO_ROOT}/charts/rhdh" \
  --namespace rhdhai-development \
  --set okp.enabled=false \
  --set rhoai.enabled=true \
  --show-only templates/rolling-demo-sidecars-job.yaml \
  > "${TEMP_DIR}/sidecars-job.yaml"

# Connector ConfigMap must exist and wire TLS + Model Catalog fields.
yq eval -e '
  .data["kserve-connector-app-config.yaml"]
  | select(test("kserve-kubeflow-connector"))
  | select(test("caData"))
  | select(test("K8S_CA_DATA"))
  | select(test("kubeflow-model-catalog-url"))
' "${TEMP_DIR}/kserve-connector-config.yaml" >/dev/null

# Sidecars job must not inject legacy connector bridge containers.
for needle in "${LEGACY_SIDECARS[@]}"; do
  if grep -Fqi -- "$needle" "${TEMP_DIR}/sidecars-job.yaml"; then
    echo "FAIL: rolling-demo-sidecars-job still references legacy connector artifact: ${needle}" >&2
    exit 1
  fi
done

# Dynamic plugins values must ship the standalone connector package.
if ! yq eval -e '
  .global.dynamic.plugins[]
  | select(.package | test("kserve-kubeflow-connector-backend"))
' "${REPO_ROOT}/charts/rhdh/values.yaml" >/dev/null; then
  echo "FAIL: values.yaml missing kserve-kubeflow-connector-backend dynamic plugin" >&2
  exit 1
fi

# Catalog provider config in values must use the connector key (not a sidecar URL).
yq eval -e '
  .backstage.upstream.backstage.appConfig.catalog.providers.modelCatalog["kserve-kubeflow-connector"]
' "${REPO_ROOT}/charts/rhdh/values.yaml" >/dev/null

echo "PASS: KServe connector Helm path has no legacy sidecars and wires caData."
