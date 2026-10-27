#!/bin/bash
# Extract CA bundle from a kubeconfig's cluster entry and generate TLS artifacts.
#
# Usage:
#   ./extract-ca-from-kubeconfig.sh <kubeconfig-path> [cluster-name]
#   ./extract-ca-from-kubeconfig.sh --list <kubeconfig-path>
#
# If cluster-name is omitted, defaults to the first cluster entry.
# Use --list to see available cluster names without extracting.
#
# Example:
#   ./extract-ca-from-kubeconfig.sh "$HOME/.kube/config"
#   ./extract-ca-from-kubeconfig.sh "$HOME/.kube/config" my-cluster-name
#
# Outputs (in the same directory as this script):
#   ca-bundle.pem       — decoded PEM CA certificate chain
#   ca-data-base64.txt  — raw base64 string for K8S_CA_DATA / caData field
#
# Then: source ./set-ca-env.sh  (exports K8S_CA_DATA + NODE_EXTRA_CA_CERTS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_HELPER="${SCRIPT_DIR}/extract_ca_from_kubeconfig.py"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <kubeconfig-path> [cluster-name]" >&2
  echo "       $0 --list <kubeconfig-path>" >&2
  exit 1
fi

if [[ "$1" == "--list" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 --list <kubeconfig-path>" >&2
    exit 1
  fi
  KUBECONFIG_PATH="$(realpath "$2")"
  exec python3 "$PY_HELPER" --list "$KUBECONFIG_PATH"
fi

KUBECONFIG_PATH="$(realpath "$1")"
CLUSTER_NAME="${2:-}"

python3 "$PY_HELPER" "$KUBECONFIG_PATH" ${CLUSTER_NAME:+"$CLUSTER_NAME"} \
  --out-dir "$SCRIPT_DIR"

echo "Generated:"
echo "  ${SCRIPT_DIR}/ca-bundle.pem"
echo "  ${SCRIPT_DIR}/ca-data-base64.txt"
echo ""
echo "Next:"
echo "  export KUBECONFIG=\"${KUBECONFIG_PATH}\""
echo "  source ${SCRIPT_DIR}/set-ca-env.sh"
echo ""
echo "Cert details:"
openssl x509 -in "${SCRIPT_DIR}/ca-bundle.pem" -noout -subject -dates 2>/dev/null || true
