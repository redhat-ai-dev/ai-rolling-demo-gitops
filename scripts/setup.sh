#!/bin/bash

# ----------- Variables ----------- #

GITOPS_OPERATOR_NAMESPACE="openshift-gitops"
GITOPS_OPERATOR_PACKAGE="openshift-gitops-operator"

PIPELINES_OPERATOR_NAMESPACE="openshift-operators"
PIPELINES_OPERATOR_PACKAGE="openshift-pipelines-operator-rh"

NFD_OPERATOR_NAMESPACE="openshift-nfd"
NFD_OPERATOR_PACKAGE="nfd"

GPU_OPERATOR_NAMESPACE="nvidia-gpu-operator"
GPU_OPERATOR_PACKAGE="gpu-operator-certified"

GITOPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="$GITOPS_DIR/deps"
SCRIPTS_DIR="$GITOPS_DIR/scripts"

source "$SCRIPTS_DIR/logging.sh"

source "$SCRIPTS_DIR/private-env"

ODH_JOB_NAME="odh-kubeflow-model-registry-setup"
ODH_JOB_NAMESPACE="odh-kubeflow-model-registry-setup"

POLL_INTERVAL=15
TIMEOUT=900

# ----------- Utils ----------- #

# check_tools: verifies that all required CLI tools are installed
check_tools() {
  local missing=()
  local tools=("oc" "kubectl" "yq" "argocd" "cosign")

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      log "'$tool' is not installed or not in PATH."
      missing+=("$tool")
    else
      log "'$tool' is installed."
    fi
  done
  if (( ${#missing[@]} )); then
    log "Missing required tools: ${missing[*]}"
    log_fail
    exit 1
  fi
}

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

# update_starting_csv: fetches the latest CSV for a package from the catalog and updates the subscription YAML
update_starting_csv() {
  local package="$1"
  local channel="$2"
  local sub_yaml="$3"

  log "Fetching latest CSV for '$package' from channel '$channel'..."
  local latest_csv
  latest_csv=$(oc get packagemanifest "$package" -n openshift-marketplace \
    -o jsonpath="{.status.channels[?(@.name==\"$channel\")].currentCSV}" 2>/dev/null)
  if [[ -z "$latest_csv" ]]; then
    log "Failed to fetch latest CSV for '$package'. Continuing with existing startingCSV."
    return 1
  fi
  log "Latest CSV for '$package': $latest_csv"
  yq eval ".spec.startingCSV = \"$latest_csv\"" -i "$DEPS_DIR/$sub_yaml"
}

# install_cluster_scoped_operator: installs an operator via a YAML file in deps/
install_cluster_scoped_operator() {
  local namespace="$1"
  local yaml_file="$2"
  local package="$3"

  ensure_namespace "$namespace"
  log "Installing operator '$package' from $yaml_file..."
  if ! oc apply -f "$DEPS_DIR/$yaml_file" >/dev/null 2>&1; then
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
  if ! oc apply -f "$DEPS_DIR/$sub_yaml" >/dev/null 2>&1; then
    log "Failed to create subscription for '$package'."
    log_fail
    exit 1
  fi
  log "Subscription for '$package' created."
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
  # Install OpenShift GitOps Operator if it doesn't exist
  if check_operator_exists "$GITOPS_OPERATOR_NAMESPACE" "$GITOPS_OPERATOR_PACKAGE"; then
    log "OpenShift GitOps Operator already installed. Skipping."
  else
    log "OpenShift GitOps Operator not found. Installing..."
    install_cluster_scoped_operator "$GITOPS_OPERATOR_NAMESPACE" "openshift-gitops-operator-subscription.yaml" "$GITOPS_OPERATOR_PACKAGE"
    wait_for_csv "$GITOPS_OPERATOR_NAMESPACE" "$GITOPS_OPERATOR_PACKAGE"
  fi

  # Install OpenShift Pipelines Operator if it doesn't exist
  if check_operator_exists "$PIPELINES_OPERATOR_NAMESPACE" "$PIPELINES_OPERATOR_PACKAGE"; then
    log "OpenShift Pipelines Operator already installed. Skipping."
  else
    log "OpenShift Pipelines Operator not found. Installing..."
    install_cluster_scoped_operator "$PIPELINES_OPERATOR_NAMESPACE" "openshift-pipelines-operator-subscription.yaml" "$PIPELINES_OPERATOR_PACKAGE"
    wait_for_csv "$PIPELINES_OPERATOR_NAMESPACE" "$PIPELINES_OPERATOR_PACKAGE"
  fi

  # Install Node Feature Discovery Operator if it doesn't exist
  if check_operator_exists "$NFD_OPERATOR_NAMESPACE" "$NFD_OPERATOR_PACKAGE"; then
    log "Node Feature Discovery Operator already installed. Skipping."
  else
    log "Node Feature Discovery Operator not found. Installing..."
    update_starting_csv "$NFD_OPERATOR_PACKAGE" "stable" "nfd-subscription.yaml"
    install_namespaced_operator "$NFD_OPERATOR_NAMESPACE" "nfd-operator-group.yaml" "nfd-subscription.yaml" "$NFD_OPERATOR_PACKAGE"
    wait_for_csv "$NFD_OPERATOR_NAMESPACE" "$NFD_OPERATOR_PACKAGE"
    # Create NFD instance
    create_nfd_instance
    wait_for_nfd_instance
  fi

  # Install Nvidia GPU Operator if it doesn't exist
  if check_operator_exists "$GPU_OPERATOR_NAMESPACE" "$GPU_OPERATOR_PACKAGE"; then
    log "NVIDIA GPU Operator already installed. Skipping."
  else
    log "NVIDIA GPU Operator not found. Installing..."
    install_namespaced_operator "$GPU_OPERATOR_NAMESPACE" "gpu-operator-group.yaml" "gpu-operator-subscription.yaml" "$GPU_OPERATOR_PACKAGE"
    wait_for_csv "$GPU_OPERATOR_NAMESPACE" "$GPU_OPERATOR_PACKAGE"
    # Create ClusterPolicy instance
    create_cluster_policy
    wait_for_cluster_policy
  fi
}

# run_rhoai_setup: applies the ODH Kubeflow Model Registry kustomize and waits for the job
run_rhoai_setup() {
  # Skip if the job already completed (e.g. on a re-run after failure)
  local job_status
  job_status=$(oc get job "$ODH_JOB_NAME" -n "$ODH_JOB_NAMESPACE" \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
  if [[ "$job_status" == "True" ]]; then
    log "Job '$ODH_JOB_NAME' already completed. Skipping."
    return 0
  fi

  log "Applying kustomize from $ODH_SETUP_DIR/kustomize-rhoai..."
  cd "$ODH_SETUP_DIR"
  if ! oc apply -k "./kustomize-rhoai" >/dev/null 2>&1; then
    log "Failed to apply kustomize-rhoai."
    log_fail
    exit 1
  fi
  log "Waiting for job '$ODH_JOB_NAME' to complete (this may take a while)..."
  if ! oc wait --for=condition=complete job/"$ODH_JOB_NAME" \
    -n "$ODH_JOB_NAMESPACE" --timeout=3600s >/dev/null 2>&1; then
    log "Job '$ODH_JOB_NAME' did not complete in time."
    log_fail
    exit 1
  fi
  log "Job '$ODH_JOB_NAME' completed."

}

# run_prepare_rolling_demo: runs the prepare-rolling-demo.sh script
run_prepare_rolling_demo() {
  log "Running prepare-rolling-demo.sh..."
  cd "$SCRIPTS_DIR"
  if ! bash ./prepare-rolling-demo.sh; then
    log "prepare-rolling-demo.sh failed."
    log_fail
    exit 1
  fi

}

# apply_argocd_application: applies the ArgoCD Application with configured values
apply_argocd_application() {
  log "Applying gitops/application.yaml..."
  cd "$GITOPS_DIR"
  local openshift_ai_url="https://rhods-dashboard-redhat-ods-applications.${RHDH_CLUSTER_ROUTER_BASE}/"
  local openshift_ai_param="global.dynamic.plugins[13].pluginConfig.dynamicPlugins.frontend.red-hat-developer-hub\\.backstage-plugin-global-header.mountPoints[13].config.props.link"
  local rhdh_namespace="${RHDH_NAMESPACE:-rolling-demo-ns}"
  if ! yq eval \
    ".spec.source.repoURL = \"$GITOPS_REPO_URL\" |
     .spec.source.targetRevision = \"$GITOPS_TARGET_REVISION\" |
     .spec.destination.namespace = \"$rhdh_namespace\" |
     .spec.source.helm.parameters = [
       {\"name\": \"global.clusterRouterBase\", \"value\": \"$RHDH_CLUSTER_ROUTER_BASE\"},
       {\"name\": \"$openshift_ai_param\", \"value\": \"$openshift_ai_url\"}
     ]" \
    gitops/application.yaml | oc apply -n openshift-gitops -f - >/dev/null 2>&1; then
    log "Failed to apply gitops/application.yaml."
    log_fail
    exit 1
  fi
  log "ArgoCD Application created successfully."
}

# ----------- main ----------- #

log "Setting Up Rolling Demo Environment..."
log "Checking if all required tools are installed..."
check_tools

# Validate required env vars
required_vars=(
  GITOPS_REPO_URL
  GITOPS_TARGET_REVISION
  RHDH_CLUSTER_ROUTER_BASE
  ODH_SETUP_DIR
  GITHUB_ORG
  GITHUB_APP_APP_ID
  GITHUB_APP_CLIENT_ID
  GITHUB_APP_CLIENT_SECRET
  GITHUB_APP_WEBHOOK_URL
  GITHUB_APP_WEBHOOK_SECRET
  GITHUB_APP_PRIVATE_KEY
  ARGOCD_USER
  BACKEND_SECRET
  RHDH_CALLBACK_URL
  POSTGRESQL_POSTGRES_PASSWORD
  POSTGRESQL_USER_PASSWORD
  QUAY_DOCKERCONFIGJSON
  KEYCLOAK_METADATA_URL
  KEYCLOAK_CLIENT_ID
  KEYCLOAK_REALM
  KEYCLOAK_BASE_URL
  KEYCLOAK_LOGIN_REALM
  KEYCLOAK_CLIENT_SECRET
  OLLAMA_URL
  OLLAMA_TOKEN
  VLLM_URL
  VLLM_API_KEY
  VALIDATION_PROVIDER
  VALIDATION_MODEL_NAME
)
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    log "Error: $var is not set. Exiting..."
    log_fail
    exit 1
  fi
done

if [[ "${SKIP_INSTALL_DEPS}" == "true" ]]; then
  log "SKIP_INSTALL_DEPS=true — skipping operator/instance installation."
else
  install_deps
fi

if [[ "${SKIP_RHOAI_SETUP}" == "true" ]]; then
  log "SKIP_RHOAI_SETUP=true — skipping ODH Kubeflow Model Registry setup."
else
  run_rhoai_setup
fi

run_prepare_rolling_demo
apply_argocd_application

log "Rolling Demo Setup Completed Successfully!"
