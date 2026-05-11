#!/bin/bash

# SCRIPTS_DIR: the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/common.sh"

# GITOPS_OPERATOR_NAMESPACE: The namespace where the OpenShift GitOps
# Operator will be installed
GITOPS_OPERATOR_NAMESPACE="openshift-gitops"
# GITOPS_OPERATOR_PACKAGE: The package name of the OpenShift GitOps
# Operator
GITOPS_OPERATOR_PACKAGE="openshift-gitops-operator"

# PIPELINES_OPERATOR_NAMESPACE: The namespace where the OpenShift Pipelines
# wll be installed
PIPELINES_OPERATOR_NAMESPACE="openshift-operators"
# PIPELINES_OPERATOR_PACKAGE: The package name of the OpenShift Pipelines
PIPELINES_OPERATOR_PACKAGE="openshift-pipelines-operator-rh"

# NFD_OPERATOR_NAMESPACE: The namespace where the Node Feature Discovery
# Operator will be installed
NFD_OPERATOR_NAMESPACE="openshift-nfd"
# NFD_OPERATOR_PACKAGE: The package name of the Node Feature Discovery
NFD_OPERATOR_PACKAGE="nfd"

# GPU_OPERATOR_NAMESPACE: The namespace where the NVIDIA GPU Operator
# will be installed
GPU_OPERATOR_NAMESPACE="nvidia-gpu-operator"
# GPU_OPERATOR_PACKAGE: The package name of the NVIDIA GPU Operator
GPU_OPERATOR_PACKAGE="gpu-operator-certified"

# POLL_INTERVAL: The interval (in seconds) to wait between checks when
# polling for CSV status or custom resource conditions.
POLL_INTERVAL=15
# TIMEOUT: The maximum time (in seconds) to wait for an operator CSV to reach
# the Succeeded phase or for custom resources to reach the desired conditions.
TIMEOUT=900

# ensure_namespace: creates a namespace if it doesn't exist
ensure_namespace() {
  local namespace="$1"

  if oc get namespace "$namespace" >/dev/null 2>&1; then
    log "Namespace '$namespace' already exists."
  else
    log "Creating namespace '$namespace'..."
    oc create namespace "$namespace" >/dev/null 2>&1
  fi
}

# check_operator_exists: checks if a subscription for the operator exists
check_operator_exists() {
  local namespace="$1"
  local package="$2"

  if oc get subscription "$package" -n "$namespace" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# wait_for_csv: waits for the CSV of an operator to reach Succeeded phase
wait_for_csv() {
  local namespace="$1"
  local package="$2"
  local timeout="${3:-$TIMEOUT}"
  local elapsed=0

  log "Waiting for CSV of '$package' in namespace '$namespace' to succeed..."
  while (( elapsed < timeout )); do
    csv=$(oc get csv -n "$namespace" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep "$package" | head -1)
    if [[ -n "$csv" ]]; then
      phase=$(oc get csv "$csv" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
      if [[ "$phase" == "Succeeded" ]]; then
        log "CSV '$csv' is in phase 'Succeeded'."
        return 0
      fi
      log "CSV '$csv' phase: '$phase'. Waiting..."
    else
      log "No CSV found for '$package' yet. Waiting..."
    fi
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done
  log "Timed out waiting for CSV of '$package' to succeed."
  log_fail
  exit 1
}

# install_cluster_scoped_operator: installs an operator via a YAML file in deps/
install_cluster_scoped_operator() {
  local namespace="$1"
  local yaml_file="$2"
  local package="$3"

  ensure_namespace "$namespace"
  log "Installing operator '$package' from $yaml_file..."
  if ! envsubst < "$DEPS_DIR/$yaml_file" | oc apply -f - >/dev/null 2>&1; then
    log "Failed to create subscription for '$package'."
    log_fail
    exit 1
  fi
  log "Subscription for '$package' created."
}

# install_namespaced_operator: creates namespace, applies OperatorGroup and Subscription from deps/
install_namespaced_operator() {
  local namespace="$1"
  local og_yaml="$2"
  local sub_yaml="$3"
  local package="$4"

  ensure_namespace "$namespace"
  log "Applying OperatorGroup from $og_yaml..."
  if ! oc apply -f "$DEPS_DIR/$og_yaml" >/dev/null 2>&1; then
    log "Failed to create OperatorGroup in '$namespace'."
    log_fail
    exit 1
  fi
  log "Installing operator '$package' from $sub_yaml..."
  if ! envsubst < "$DEPS_DIR/$sub_yaml" | oc apply -f - >/dev/null 2>&1; then
    log "Failed to create subscription for '$package'."
    log_fail
    exit 1
  fi
  log "Subscription for '$package' created."
}

# resolve_nfd_starting_csv: auto-detects the latest NFD CSV for NFD_OPERATOR_CHANNEL
# if NFD_STARTING_CSV is not already set by the user.
resolve_nfd_starting_csv() {
  if [[ -n "$NFD_STARTING_CSV" ]]; then
    log "Using user-provided NFD_STARTING_CSV: $NFD_STARTING_CSV"
    return 0
  fi
  log "NFD_STARTING_CSV not set, detecting latest CSV for channel '$NFD_OPERATOR_CHANNEL'..."
  NFD_STARTING_CSV=$(oc get packagemanifest nfd -n openshift-marketplace \
    -o jsonpath="{.status.channels[?(@.name==\"${NFD_OPERATOR_CHANNEL}\")].currentCSV}" 2>/dev/null)
  if [[ -z "$NFD_STARTING_CSV" ]]; then
    log "Failed to detect NFD CSV for channel '$NFD_OPERATOR_CHANNEL'."
    log_fail
    exit 1
  fi
  log "Detected NFD_STARTING_CSV: $NFD_STARTING_CSV"
  export NFD_STARTING_CSV
}

# create_nfd_instance: creates a NodeFeatureDiscovery CR from deps/
create_nfd_instance() {
  log "Creating NodeFeatureDiscovery instance..."
  if ! oc apply -f "$DEPS_DIR/nfd-instance.yaml" >/dev/null 2>&1; then
    log "Failed to create NodeFeatureDiscovery instance."
    log_fail
    exit 1
  fi
  log "NodeFeatureDiscovery instance created."
}

# wait_for_nfd_instance: waits for NFD instance to be Available/Upgradeable
# shellcheck disable=SC2120
wait_for_nfd_instance() {
  local timeout="${1:-$TIMEOUT}"
  local elapsed=0

  log "Waiting for NodeFeatureDiscovery instance to be Available (this might take ~2 minutes)..."
  while (( elapsed < timeout )); do
    available=$(oc get nodefeaturediscovery nfd-instance -n "$NFD_OPERATOR_NAMESPACE" \
      -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    if [[ "$available" == "True" ]]; then
      log "NodeFeatureDiscovery instance is Available."
      return 0
    fi
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done
  log "Timed out waiting for NodeFeatureDiscovery instance."
  log_fail
  exit 1
}

# create_cluster_policy: creates an NVIDIA ClusterPolicy CR from deps/
create_cluster_policy() {
  log "Creating NVIDIA ClusterPolicy instance..."
  if ! oc apply -f "$DEPS_DIR/gpu-cluster-policy.yaml" >/dev/null 2>&1; then
    log "Failed to create ClusterPolicy."
    log_fail
    exit 1
  fi
  log "ClusterPolicy created."
}

# wait_for_cluster_policy: waits for ClusterPolicy status to be ready
# shellcheck disable=SC2120
wait_for_cluster_policy() {
  local timeout="${1:-$TIMEOUT}"
  local elapsed=0

  log "Waiting for ClusterPolicy to be ready (this might take ~10 minutes)..."
  while (( elapsed < timeout )); do
    state=$(oc get clusterpolicy gpu-cluster-policy \
      -o jsonpath='{.status.state}' 2>/dev/null)
    if [[ "$state" == "ready" ]]; then
      log "ClusterPolicy is ready."
      return 0
    fi
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done
  log "Timed out waiting for ClusterPolicy to be ready."
  log_fail
  exit 1
}

# install_deps: installs all required operators and their instances
install_deps() {
  # install OpenShift GitOps Operator if it doesn't exist
  if check_operator_exists "$GITOPS_OPERATOR_NAMESPACE" "$GITOPS_OPERATOR_PACKAGE"; then
    log "OpenShift GitOps Operator already installed. Skipping."
  else
    log "OpenShift GitOps Operator not found. Installing..."
    install_cluster_scoped_operator "$GITOPS_OPERATOR_NAMESPACE" "openshift-gitops-operator-subscription.yaml" "$GITOPS_OPERATOR_PACKAGE"
    wait_for_csv "$GITOPS_OPERATOR_NAMESPACE" "$GITOPS_OPERATOR_PACKAGE"
  fi

  # install OpenShift Pipelines Operator if it doesn't exist
  if check_operator_exists "$PIPELINES_OPERATOR_NAMESPACE" "$PIPELINES_OPERATOR_PACKAGE"; then
    log "OpenShift Pipelines Operator already installed. Skipping."
  else
    log "OpenShift Pipelines Operator not found. Installing..."
    install_cluster_scoped_operator "$PIPELINES_OPERATOR_NAMESPACE" "openshift-pipelines-operator-subscription.yaml" "$PIPELINES_OPERATOR_PACKAGE"
    wait_for_csv "$PIPELINES_OPERATOR_NAMESPACE" "$PIPELINES_OPERATOR_PACKAGE"
  fi

  if [[ "${SKIP_RHOAI_SETUP}" == "true" ]]; then
    log "SKIP_RHOAI_SETUP=true — skipping NFD and GPU operator installation."
  else
    # install Node Feature Discovery Operator if it doesn't exist
    if check_operator_exists "$NFD_OPERATOR_NAMESPACE" "$NFD_OPERATOR_PACKAGE"; then
      log "Node Feature Discovery Operator already installed. Skipping."
    else
      log "Node Feature Discovery Operator not found. Installing..."
      resolve_nfd_starting_csv
      install_namespaced_operator "$NFD_OPERATOR_NAMESPACE" "nfd-operator-group.yaml" "nfd-subscription.yaml" "$NFD_OPERATOR_PACKAGE"
      wait_for_csv "$NFD_OPERATOR_NAMESPACE" "$NFD_OPERATOR_PACKAGE"
      # create NFD instance
      create_nfd_instance
      wait_for_nfd_instance
    fi

    # install Nvidia GPU Operator if it doesn't exist
    if check_operator_exists "$GPU_OPERATOR_NAMESPACE" "$GPU_OPERATOR_PACKAGE"; then
      log "NVIDIA GPU Operator already installed. Skipping."
    else
      log "NVIDIA GPU Operator not found. Installing..."
      install_namespaced_operator "$GPU_OPERATOR_NAMESPACE" "gpu-operator-group.yaml" "gpu-operator-subscription.yaml" "$GPU_OPERATOR_PACKAGE"
      wait_for_csv "$GPU_OPERATOR_NAMESPACE" "$GPU_OPERATOR_PACKAGE"
      # create ClusterPolicy instance
      create_cluster_policy
      wait_for_cluster_policy
    fi
  fi
}

install_deps
