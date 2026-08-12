#!/bin/bash

# GITOPS_DIR: the root of the gitops repo
GITOPS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# DEPS_DIR: the directory where dependency
# shellcheck disable=SC2034
DEPS_DIR="$GITOPS_DIR/deps"

source "$SCRIPTS_DIR/logging.sh"

# ARGOCD_NAMESPACE: The namespace where ArgoCD is installed
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-openshift-gitops}"

# PAC_NAMESPACE: The namespace where OpenShift Pipelines (and Pipelines-as-Code) runs
PAC_NAMESPACE="${PAC_NAMESPACE:-openshift-pipelines}"

# LIGHTSPEED_POSTGRES_NAMESPACE: The namespace where the LightSpeed PostgreSQL instance is deployed
LIGHTSPEED_POSTGRES_NAMESPACE="${LIGHTSPEED_POSTGRES_NAMESPACE:-lightspeed-postgres}"

# RHDH_NAMESPACE: The namespace where the RHDH instance will be deployed
RHDH_NAMESPACE="${RHDH_NAMESPACE:-rolling-demo-ns}"

# ARGOCD_APP_NAME: The name of the ArgoCD application that will be deployed
ARGOCD_APP_NAME="${ARGOCD_APP_NAME:-rolling-demo}"

# GitOps operator subscription settings
GITOPS_OPERATOR_CHANNEL="${GITOPS_OPERATOR_CHANNEL:-latest}"
GITOPS_STARTING_CSV="${GITOPS_STARTING_CSV:-openshift-gitops-operator.v1.19.1}"

# Pipelines operator subscription settings
PIPELINES_OPERATOR_CHANNEL="${PIPELINES_OPERATOR_CHANNEL:-latest}"
PIPELINES_STARTING_CSV="${PIPELINES_STARTING_CSV:-openshift-pipelines-operator-rh.v1.23.1}"

# NFD operator subscription settings
# If NFD_STARTING_CSV is not set, it will be auto-detected from the cluster catalog.
NFD_OPERATOR_CHANNEL="${NFD_OPERATOR_CHANNEL:-stable}"
NFD_STARTING_CSV="${NFD_STARTING_CSV:-}"

# GPU operator subscription settings
GPU_OPERATOR_CHANNEL="${GPU_OPERATOR_CHANNEL:-v25.10}"
GPU_STARTING_CSV="${GPU_STARTING_CSV:-gpu-operator-certified.v25.10.1}"
