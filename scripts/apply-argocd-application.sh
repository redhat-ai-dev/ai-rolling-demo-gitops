#!/bin/bash

# SCRIPTS_DIR: the directory where this script is located
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPTS_DIR/common.sh"

# apply_argocd_application: applies the ArgoCD Application with configured values
apply_argocd_application() {
  log "Applying gitops/application.yaml..."
  cd "$GITOPS_DIR" || { log "Failed to cd into $GITOPS_DIR. Exiting."; log_fail; exit 1; }
  local openshift_ai_url="https://rhods-dashboard-redhat-ods-applications.${RHDH_CLUSTER_ROUTER_BASE}/"
  local openshift_ai_param="global.dynamic.plugins[12].pluginConfig.dynamicPlugins.frontend.red-hat-developer-hub\\.backstage-plugin-global-header.mountPoints[13].config.props.link"
  local rhdh_namespace="${RHDH_NAMESPACE:-rolling-demo-ns}"
  local argocd_app_name="${ARGOCD_APP_NAME:-rolling-demo}"
  if oc get application "$argocd_app_name" -n openshift-gitops >/dev/null 2>&1; then
    log "ArgoCD Application '$argocd_app_name' already exists. Exiting."
    log_fail
    exit 1
  fi
  local helm_params
  if [[ "${SKIP_RHOAI_SETUP}" == "true" ]]; then
    helm_params="[
       {\"name\": \"global.clusterRouterBase\", \"value\": \"$RHDH_CLUSTER_ROUTER_BASE\"},
       {\"name\": \"global.isSecondaryInstance\", \"value\": \"${IS_SECONDARY_INSTANCE:-false}\"}
       {\"name\": \"rhoai.enabled\", \"value\": \"false\"}
     ]"
  else
    helm_params="[
       {\"name\": \"global.clusterRouterBase\", \"value\": \"$RHDH_CLUSTER_ROUTER_BASE\"},
       {\"name\": \"global.isSecondaryInstance\", \"value\": \"${IS_SECONDARY_INSTANCE:-false}\"},
       {\"name\": \"$openshift_ai_param\", \"value\": \"$openshift_ai_url\"},
     ]"
  fi
  if ! yq eval \
    ".metadata.name = \"$argocd_app_name\" |
     .spec.source.repoURL = \"$GITOPS_REPO_URL\" |
     .spec.source.targetRevision = \"$GITOPS_TARGET_REVISION\" |
     .spec.destination.namespace = \"$rhdh_namespace\" |
     .spec.source.helm.parameters = ${helm_params}" \
    gitops/application.yaml | oc apply -n openshift-gitops -f - >/dev/null 2>&1; then
    log "Failed to apply gitops/application.yaml."
    log_fail
    exit 1
  fi
  log "ArgoCD Application created successfully."
}

apply_argocd_application
