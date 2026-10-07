#!/usr/bin/env bash
# Assert rolling-demo values wire the OGX entity provider under the
# ai-catalog.entityProviders.ogx namespace (not legacy boost.entityProviders.ogx).
#
# Mirrors RHIDP-16560 / RHIDP-17280: after the AI Catalog rename, the standalone
# ogx-entity-provider plugin ignores boost.* provider namespaces.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALUES="${REPO_ROOT}/charts/rhdh/values.yaml"

# Dynamic plugins values must ship OGX + AI Catalog packages (Kind Extensions UI
# often has an empty installed-packages table, so assert packages here instead).
REQUIRED_PACKAGES=(
  ogx-entity-provider
  ai-catalog
  catalog-backend-module-ai-resource-agent
  catalog-backend-module-ai-model-server
)
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if ! yq eval -e "
    .global.dynamic.plugins[]
    | select(.package | test(\"${pkg}\"))
  " "${VALUES}" >/dev/null; then
    echo "FAIL: values.yaml missing dynamic plugin matching ${pkg}" >&2
    exit 1
  fi
done

# Catalog provider config must use the AI Catalog namespace.
yq eval -e '
  .backstage.upstream.backstage.appConfig["ai-catalog"].entityProviders.ogx.baseUrl
' "${VALUES}" >/dev/null

yq eval -e '
  .backstage.upstream.backstage.appConfig["ai-catalog"].entityProviders.ogx.agents
  | length > 0
' "${VALUES}" >/dev/null

# Legacy boost.entityProviders.ogx must not remain (plugin ignores it).
if yq eval -e '
  .backstage.upstream.backstage.appConfig.boost.entityProviders.ogx
' "${VALUES}" >/dev/null 2>&1; then
  echo "FAIL: values.yaml still has boost.entityProviders.ogx (ignored by plugin)" >&2
  exit 1
fi

echo "PASS: OGX entity provider is configured under ai-catalog.entityProviders.ogx."
