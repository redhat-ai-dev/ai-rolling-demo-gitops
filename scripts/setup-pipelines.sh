#!/bin/bash

# SCRIPTS_DIR: the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/common.sh"

# configure_cosign_signing_secret: configures signing secret
configure_cosign_signing_secret() {
  local namespace="${1:-openshift-pipelines}"
  local random_pass

  random_pass=$(openssl rand -base64 30)
  log "Deleting existing 'signing-secrets' secret (if it exists)..."
  kubectl delete secret "signing-secrets" -n "$namespace" --ignore-not-found=true >/dev/null 2>&1
  log "Generating new Cosign key pair into 'signing-secrets'..."
  if ! env COSIGN_PASSWORD="$random_pass" cosign generate-key-pair "k8s://$namespace/signing-secrets" >/dev/null 2>&1; then
    log "Failed to generate cosign key pair. Exiting."
    log_fail
    return 1
  fi
  log "Marking 'signing-secrets' as immutable..."
  kubectl patch secret "signing-secrets" -n "$namespace" \
    --dry-run=client -o yaml \
    --patch='{"immutable": true}' 2>/dev/null \
    | kubectl apply -f - >/dev/null 2>&1
  log "Cosign signing secret configured and made immutable."
}

# if this is not a secondary instance (meaning we have already an RHDH instance in the cluster)
# we need to configure the cosign signing secret
if [[ "${IS_SECONDARY_INSTANCE}" != "true" ]]; then
  log "Configuring Cosign signing secrets in namespace '$PAC_NAMESPACE'..."
  configure_cosign_signing_secret "$PAC_NAMESPACE"
fi

if ! (cd "$SCRIPTS_DIR" && bash ./configure-pipelines.sh); then
  log "Tekton Pipelines configuration failed."
  log_fail
  exit 1
fi
log "Tekton Pipelines configured successfully"
