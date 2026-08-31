#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

cp -R "$REPO_ROOT/charts/rhdh" "$TEMP_DIR/rhdh"

helm template rolling-demo "$TEMP_DIR/rhdh" \
  --namespace rhdhai-development \
  --set okp.enabled=false \
  --show-only templates/rolling-demo-sidecars-job.yaml \
  > "$TEMP_DIR/rendered-job.yaml"

helm template rolling-demo "$TEMP_DIR/rhdh" \
  --namespace rhdhai-development \
  --set okp.enabled=false \
  --show-only templates/lightspeed-stack-config.yaml \
  | yq eval -r '.data["lightspeed-stack.yaml"]' - \
  | yq eval -e '.skills.paths[] | select(. == "/app-root/skills")' - >/dev/null

yq eval -r \
  '.spec.template.spec.containers[] | select(.name == "patch-deployment") | .args[0]' \
  "$TEMP_DIR/rendered-job.yaml" \
  > "$TEMP_DIR/patch-deployment.sh"

cat > "$TEMP_DIR/deployment.json" <<'EOF'
{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {"name": "lightspeed-data", "emptyDir": {}},
          {"name": "lightspeed-rag", "emptyDir": {}}
        ],
        "initContainers": [
          {"name": "lightspeed-rag-init"}
        ],
        "containers": [
          {"name": "backstage-backend", "volumeMounts": []},
          {
            "name": "lightspeed-core",
            "volumeMounts": [
              {
                "name": "gcp-creds",
                "mountPath": "/app-root/gcp-creds.json",
                "subPath": "gcp-creds.json",
                "readOnly": true
              }
            ]
          }
        ]
      }
    }
  }
}
EOF

mkdir -p "$TEMP_DIR/bin"
cat > "$TEMP_DIR/bin/kubectl" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

if [ "$1" = "rollout" ]; then
  exit 0
fi

if [ "$1" = "get" ]; then
  cat "$FAKE_DEPLOYMENT"
  exit 0
fi

if [ "$1" = "patch" ]; then
  for argument in "$@"; do
    case "$argument" in
      --patch=*)
        printf '%s\n' "${argument#--patch=}" > "$CAPTURE_PATCH"
        exit 0
        ;;
    esac
  done
fi

echo "Unexpected kubectl invocation: $*" >&2
exit 1
EOF
chmod +x "$TEMP_DIR/bin/kubectl"

PATH="$TEMP_DIR/bin:$PATH" \
FAKE_DEPLOYMENT="$TEMP_DIR/deployment.json" \
CAPTURE_PATCH="$TEMP_DIR/patch.json" \
bash "$TEMP_DIR/patch-deployment.sh" >/dev/null

jq -e '
  any(.[];
    .path == "/spec/template/spec/volumes/-" and
    .value.name == "lightspeed-skills" and
    .value.emptyDir == {}
  )
' "$TEMP_DIR/patch.json" >/dev/null

jq -e '
  any(.[];
    .path == "/spec/template/spec/initContainers/-" and
    .value.name == "fetch-lightspeed-skills" and
    .value.image == "quay.io/redhat-ai-dev/utils:latest" and
    (.value.args[0] | contains("https://github.com/redhat-developer/rhdh-skills.git")) and
    (.value.volumeMounts | any(.name == "lightspeed-skills" and .mountPath == "/skills"))
  )
' "$TEMP_DIR/patch.json" >/dev/null

jq -e '
  any(.[];
    .path == "/spec/template/spec/containers/1/volumeMounts/-" and
    .value.name == "lightspeed-skills" and
    .value.mountPath == "/app-root/skills" and
    (.value | has("readOnly") | not)
  )
' "$TEMP_DIR/patch.json" >/dev/null

cat > "$TEMP_DIR/deployment.json" <<'EOF'
{
  "spec": {
    "template": {
      "spec": {
        "volumes": [
          {"name": "lightspeed-data", "emptyDir": {}},
          {"name": "lightspeed-rag", "emptyDir": {}},
          {"name": "lightspeed-skills", "emptyDir": {"medium": "Memory"}}
        ],
        "initContainers": [
          {"name": "lightspeed-rag-init"},
          {"name": "fetch-lightspeed-skills", "image": "old-image"}
        ],
        "containers": [
          {"name": "backstage-backend", "volumeMounts": []},
          {
            "name": "lightspeed-core",
            "volumeMounts": [
              {
                "name": "gcp-creds",
                "mountPath": "/app-root/gcp-creds.json",
                "subPath": "gcp-creds.json",
                "readOnly": true
              },
              {"name": "lightspeed-skills", "mountPath": "/old-skills"}
            ]
          }
        ]
      }
    }
  }
}
EOF

PATH="$TEMP_DIR/bin:$PATH" \
FAKE_DEPLOYMENT="$TEMP_DIR/deployment.json" \
CAPTURE_PATCH="$TEMP_DIR/patch.json" \
bash "$TEMP_DIR/patch-deployment.sh" >/dev/null

jq -e '
  any(.[];
    .op == "replace" and
    .path == "/spec/template/spec/volumes/2" and
    .value.name == "lightspeed-skills" and
    .value.emptyDir == {}
  ) and
  any(.[];
    .op == "replace" and
    .path == "/spec/template/spec/initContainers/1" and
    .value.name == "fetch-lightspeed-skills"
  ) and
  any(.[];
    .op == "replace" and
    .path == "/spec/template/spec/containers/1/volumeMounts/1" and
    .value.name == "lightspeed-skills" and
    .value.mountPath == "/app-root/skills" and
    (.value | has("readOnly") | not)
  )
' "$TEMP_DIR/patch.json" >/dev/null

echo "Skills volume patch test passed."
