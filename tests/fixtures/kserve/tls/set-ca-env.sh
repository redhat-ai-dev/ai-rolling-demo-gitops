#!/bin/bash
# Source this file to export K8S_CA_DATA / NODE_EXTRA_CA_CERTS for connector TLS.
#
# Prerequisites:
#   1. Run extract-ca-from-kubeconfig.sh against your target kubeconfig so that
#      ca-bundle.pem and ca-data-base64.txt exist next to this script.
#   2. Optionally export KUBECONFIG to the same kubeconfig path.
#   3. Optionally export K8S_SA_TOKEN (bearer) before sourcing — needed when the
#      kubeconfig uses client-certificate auth and fetchModelCard hits cluster routes.
#
# Usage (from repo root):
#   ./tests/fixtures/kserve/tls/extract-ca-from-kubeconfig.sh "$KUBECONFIG" [cluster-name]
#   source ./tests/fixtures/kserve/tls/set-ca-env.sh
#   # then: export K8S_CA_DATA into scripts/private-env and re-run setup-secrets
#
# See OCP-SET-UP-CLIENT-TLS.md (RHIDP-14261 attachment) for when caData is required
# vs ROSA/Let's Encrypt clusters where it can be omitted.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_DATA_FILE="${SCRIPT_DIR}/ca-data-base64.txt"
CA_BUNDLE_FILE="${SCRIPT_DIR}/ca-bundle.pem"

if [[ ! -f "$CA_DATA_FILE" ]]; then
  echo "ERROR: ${CA_DATA_FILE} missing. Run extract-ca-from-kubeconfig.sh first." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ! -f "$CA_BUNDLE_FILE" ]]; then
  echo "ERROR: ${CA_BUNDLE_FILE} missing. Run extract-ca-from-kubeconfig.sh first." >&2
  return 1 2>/dev/null || exit 1
fi

export K8S_CA_DATA="$(cat "${CA_DATA_FILE}")"
export NODE_EXTRA_CA_CERTS="${CA_BUNDLE_FILE}"

if [[ -n "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG
else
  echo "NOTE: KUBECONFIG is unset; set it if you need kubectl/oc against the same cluster."
fi

# Some kubeconfigs use client-certificate auth (no bearer token).
# fetchModelCard needs a bearer token for HTTPS calls to cluster routes.
if [[ -n "${K8S_SA_TOKEN:-}" ]]; then
  export K8S_TOKEN="$K8S_SA_TOKEN"
  echo "K8S_TOKEN set from K8S_SA_TOKEN"
else
  echo "WARNING: K8S_SA_TOKEN not set — export K8S_SA_TOKEN=<token> before sourcing if needed"
fi

echo "KUBECONFIG=${KUBECONFIG:-<unset>}"
echo "K8S_CA_DATA set ($(echo -n "$K8S_CA_DATA" | wc -c | tr -d ' ') bytes)"
echo "NODE_EXTRA_CA_CERTS=${NODE_EXTRA_CA_CERTS}"
