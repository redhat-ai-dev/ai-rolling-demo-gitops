#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

helm template rolling-demo "$repo_root/charts/rhdh" \
  --namespace rolling-demo-ns \
  --kube-version 1.31.0 \
  -f "$repo_root/ci/values-ci.yaml" > "$rendered"

yq -o=json '.' "$rendered" | jq -s -e '
  (all(.[]; .kind != "Route")) and
  (all(.[]; .kind != "Deployment" or (.metadata.name | contains("okp") | not))) and
  ([.[] | select(.kind == "Deployment" and .metadata.name == "rolling-demo-backstage")]
   | length == 1 and
     (.[0].spec.template.spec as $pod |
       ($pod.initContainers | any(.name == "byok-rag-init" and
         .image == "busybox:1.38.0" and
         (.volumeMounts | any(.name == "lightspeed-data" and .mountPath == "/tmp")))) and
       ($pod.initContainers | any(.name == "fetch-lightspeed-skills" and
         (.volumeMounts | any(.name == "lightspeed-skills" and .mountPath == "/skills")))) and
       ($pod.containers | any(.name == "feedback-harvester"))
     )) and
  ([.[] | select(.kind == "StatefulSet" and .metadata.name == "rolling-demo-postgresql")]
   | length == 1 and
     (.[0].spec.template.spec.containers[0] as $db |
       $db.image == "quay.io/fedora/postgresql-15:latest" and
       $db.securityContext.readOnlyRootFilesystem == false and
       $db.securityContext.runAsGroup == 0 and
       ($db.env | any(.name == "POSTGRESQL_ADMIN_PASSWORD" and
         .valueFrom.secretKeyRef.name == "rolling-demo-postgresql"))))
' > /dev/null

app_config="$(yq -r 'select(.kind == "ConfigMap" and .metadata.name == "rolling-demo-backstage-app-config") | .data."app-config.yaml"' "$rendered")"
if [[ -z "$app_config" ]]; then
  echo "Missing CI app config" >&2
  exit 1
fi
if ! printf '%s\n' "$app_config" | yq -o=json '.' | jq -e '
  .permission.enabled == false and
  (."intelligent-assistant".mcpServers | any(.name == "mcp-integration-tools" and .token == "${MCP_TOKEN}"))
' > /dev/null; then
  echo "CI app config lost its permission or MCP override" >&2
  exit 1
fi

yq -e '.nodes[0].image == "kindest/node:v1.31.2@sha256:18fbefc20a7113353c7b75b5c869d7145a6abd6269154825872dc59c1329912e"' \
  "$repo_root/ci/kind-config.yaml" > /dev/null

echo "RHDH CI values render for the 2.1 chart"
