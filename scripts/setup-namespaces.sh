#!/bin/bash

# is_openshift: returns true if the current cluster exposes OpenShift APIs
is_openshift() {
  kubectl api-resources --api-group=project.openshift.io --no-headers 2>/dev/null | grep -q .
}

# create_namespace: creates a namespace/project using oc on OpenShift or kubectl on vanilla k8s
create_namespace() {
  local namespace="$1"

  if is_openshift; then
    if oc get project "$namespace" >/dev/null 2>&1; then
      log "Project '$namespace' already exists."
    else
      log "Creating project '$namespace'..."
      if oc new-project "$namespace" >/dev/null 2>&1; then
        log "Project '$namespace' created successfully."
      else
        log "Failed to create project '$namespace'. Exiting."
        log_fail
        exit 1
      fi
    fi
  else
    log "Creating namespace '$namespace'..."
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    log "Namespace '$namespace' created successfully."
  fi
}

# add_argocd_label: labels a given namespace for ArgoCD management (OpenShift only)
add_argocd_label() {
  local namespace="$1"
  local argocd_namespace="${2:-openshift-gitops}"

  if ! oc label namespace "$namespace" "argocd.argoproj.io/managed-by=$argocd_namespace" --overwrite >/dev/null 2>&1; then
    log "Failed to label namespace '$namespace'. Exiting."
    log_fail
    return 1
  fi
  log "Project '$namespace' labeled successfully."
}

log "Creating new namespace for $RHDH_NAMESPACE..."
create_namespace "$RHDH_NAMESPACE"

# lightspeed-postgres namespace is only needed on OpenShift (requires ArgoCD and RHOAI)
if is_openshift; then
  log "Creating new project for $LIGHTSPEED_POSTGRES_NAMESPACE..."
  create_namespace "$LIGHTSPEED_POSTGRES_NAMESPACE"

  log "Labeling $LIGHTSPEED_POSTGRES_NAMESPACE for ArgoCD management..."
  add_argocd_label "$LIGHTSPEED_POSTGRES_NAMESPACE"
fi
