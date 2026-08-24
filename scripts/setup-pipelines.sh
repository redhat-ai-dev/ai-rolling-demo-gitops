#!/bin/bash

# SCRIPTS_DIR: the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/common.sh"

# configure_cosign_signing_secret: configures signing secret
# Waits for the Tekton operator to create the signing-secrets placeholder,
# then populates it with generated keys and marks it immutable.
configure_cosign_signing_secret() {
  local namespace="${1:-openshift-pipelines}"
  local random_pass
  local temp_dir
  local timeout=120
  local elapsed=0

  # Wait for Tekton operator to create the signing-secrets (may be empty)
  log "Waiting for Tekton operator to create 'signing-secrets'..."
  while ! kubectl get secret "signing-secrets" -n "$namespace" >/dev/null 2>&1; do
    if (( elapsed >= timeout )); then
      log "Timed out waiting for signing-secrets. Exiting."
      log_fail
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  # Check if secret already has keys (from previous run or operator)
  if kubectl get secret "signing-secrets" -n "$namespace" -o jsonpath='{.data.cosign\.pub}' 2>/dev/null | grep -q .; then
    log "signing-secrets already has keys. Skipping generation."
    return 0
  fi

  random_pass=$(openssl rand -base64 30)
  temp_dir=$(mktemp -d)
  log "Generating Cosign key pair to temp files..."
  if ! (cd "$temp_dir" && env COSIGN_PASSWORD="$random_pass" cosign generate-key-pair >/dev/null 2>&1); then
    log "Failed to generate cosign key pair. Exiting."
    rm -rf "$temp_dir"
    log_fail
    return 1
  fi

  log "Patching 'signing-secrets' with generated keys..."
  kubectl create secret generic "signing-secrets" \
    --from-file=cosign.pub="$temp_dir/cosign.pub" \
    --from-file=cosign.key="$temp_dir/cosign.key" \
    --from-file=cosign.password=<(echo -n "$random_pass") \
    --namespace="$namespace" \
    --dry-run=client -o yaml \
    | kubectl apply -f - >/dev/null 2>&1

  rm -rf "$temp_dir"

  log "Marking 'signing-secrets' as immutable..."
  kubectl patch secret "signing-secrets" -n "$namespace" \
    --type merge \
    --patch='{"immutable": true}' >/dev/null 2>&1
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
