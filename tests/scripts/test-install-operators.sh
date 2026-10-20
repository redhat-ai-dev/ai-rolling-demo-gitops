#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$TEMP_DIR/bin"

cat > "$TEMP_DIR/bin/oc" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

if [[ "$1" == "get" && "$2" == "subscription" ]]; then
  [[ "$3" == "openshift-gitops-operator" ]]
  exit
fi

if [[ "$1" == "get" && "$2" == "namespace" ]]; then
  exit 0
fi

if [[ "$1" == "apply" ]]; then
  command cat >/dev/null
  exit 0
fi

if [[ "$1" == "get" && "$2" == "installplan" ]]; then
  printf '{"items":[]}'
  exit 0
fi

if [[ "$1" == "get" && "$2" == "csv" && "$3" == "-n" ]]; then
  printf 'openshift-pipelines-operator-rh.v1.23.1'
  exit 0
fi

if [[ "$1" == "get" && "$2" == "csv" ]]; then
  printf 'Succeeded'
  exit 0
fi

printf 'Unexpected oc invocation: %s\n' "$*" >&2
exit 1
EOF

cat > "$TEMP_DIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail
printf '%s\n' "$1" >> "$SLEEP_LOG"
EOF

cat > "$TEMP_DIR/bin/envsubst" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail
command cat
EOF

chmod +x "$TEMP_DIR/bin/oc" "$TEMP_DIR/bin/sleep" "$TEMP_DIR/bin/envsubst"

PATH="$TEMP_DIR/bin:$PATH" \
SLEEP_LOG="$TEMP_DIR/sleep.log" \
SKIP_RHOAI_SETUP=true \
bash "$REPO_ROOT/scripts/install-operators.sh" > "$TEMP_DIR/output.log"

if ! grep -F "Looking for pending install plan containing 'openshift-pipelines-operator-rh.v1.23.1' in namespace 'openshift-operators' for up to 60 seconds..." "$TEMP_DIR/output.log" >/dev/null; then
  printf 'Expected pending install plan log to state the 60-second timeout\n' >&2
  exit 1
fi

actual_wait=$(awk '{ total += $1 } END { print total + 0 }' "$TEMP_DIR/sleep.log")
if [[ "$actual_wait" -ne 60 ]]; then
  printf 'Expected pending install plan lookup to wait 60 seconds, waited %s seconds\n' "$actual_wait" >&2
  exit 1
fi
