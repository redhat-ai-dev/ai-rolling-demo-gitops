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

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <kubeconfig-path> [cluster-name]" >&2
  echo "       $0 --list <kubeconfig-path>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$1" == "--list" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "Usage: $0 --list <kubeconfig-path>" >&2
    exit 1
  fi
  KUBECONFIG_PATH="$(realpath "$2")"
  if [[ ! -f "$KUBECONFIG_PATH" ]]; then
    echo "Error: kubeconfig not found at $KUBECONFIG_PATH" >&2
    exit 1
  fi
  python3 -c "
import yaml
with open('${KUBECONFIG_PATH}') as f:
    kc = yaml.safe_load(f)
print('Clusters in ${KUBECONFIG_PATH}:')
for c in kc['clusters']:
    server = c['cluster'].get('server', '(unknown)')
    has_ca = 'yes' if c['cluster'].get('certificate-authority-data') else 'no'
    print(f\"  {c['name']}  server={server}  ca-data={has_ca}\")
"
  exit 0
fi

KUBECONFIG_PATH="$(realpath "$1")"
CLUSTER_NAME="${2:-}"

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "Error: kubeconfig not found at $KUBECONFIG_PATH" >&2
  exit 1
fi

python3 -c "
import yaml, base64, sys

with open('${KUBECONFIG_PATH}') as f:
    kc = yaml.safe_load(f)

cluster_name = '${CLUSTER_NAME}'
target = None

if not cluster_name:
    target = kc['clusters'][0]
    cluster_name = target['name']
    print(f'No cluster name given, using first entry: {cluster_name}')
else:
    for c in kc['clusters']:
        if c['name'] == cluster_name:
            target = c
            break

if not target:
    print(f\"Error: cluster '{cluster_name}' not found in kubeconfig\", file=sys.stderr)
    print('Available clusters:', file=sys.stderr)
    for c in kc['clusters']:
        print(f\"  - {c['name']}\", file=sys.stderr)
    sys.exit(1)

ca_b64 = target['cluster'].get('certificate-authority-data')
if not ca_b64:
    print(f\"Error: cluster '{cluster_name}' has no certificate-authority-data\", file=sys.stderr)
    sys.exit(1)

pem = base64.b64decode(ca_b64).decode('utf-8')
with open('${SCRIPT_DIR}/ca-bundle.pem', 'w') as out:
    out.write(pem)
with open('${SCRIPT_DIR}/ca-data-base64.txt', 'w') as out:
    out.write(ca_b64)
count = pem.count('BEGIN CERTIFICATE')
server = target['cluster'].get('server', '(unknown)')
print(f'Extracted {count} CA certificates for cluster {cluster_name} ({server})')
"

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
