#!/bin/bash

# source the private env
# usually is called from scripts/prepare-rolling-demo
# so all env vars have been checked.
source ./private-env

# Constants
CRD="tektonconfigs"
NAMESPACE="rolling-demo-ns"
BASE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
PAC_NAMESPACE="openshift-pipelines"

# Update the tekton config to add the transparency url
echo -n "* Update the TektonConfig resource: "
until kubectl get tektonconfig config >/dev/null 2>&1; do
    echo -n "_"
    sleep 3
done
TEKTON_CONFIG=$(yq ".spec.chain.\"transparency.url\" = \"http://rekor-server.${NAMESPACE}.svc\"" $BASE_DIR/resources/tekton-config.yaml -M -I=0 -o='json')
kubectl patch tektonconfig config --type 'merge' --patch "${TEKTON_CONFIG}" >/dev/null
if [ $? -ne 0 ]; then
    echo "FAIL"
    exit 1
fi
echo "OK"

# Fetching cosign public key
# Fetches cosign public key needed for namespace setup
echo -n "* Fetching cosign public key: "
while ! kubectl get secrets -n $PAC_NAMESPACE  signing-secrets >/dev/null 2>&1; do
    echo -n "_"
    sleep 2
done
echo -n "."
COSIGN_SIGNING_PUBLIC_KEY=""
while [ -z "${COSIGN_SIGNING_PUBLIC_KEY:-}" ]; do
    echo -n "_"
    sleep 2
    COSIGN_SIGNING_PUBLIC_KEY=$(kubectl get secrets -n $PAC_NAMESPACE signing-secrets -o jsonpath='{.data.cosign\.pub}' 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi
done
echo "OK"

# Creating Namespace Setup Tekton Task Definition
# Creates Tekton Task definition for creating custom namespaces with needed resources
echo -n "* Creating Namespace Setup Tekton Task Definition: "
DEV_SETUP_TASK=$(cat $BASE_DIR/resources/dev-setup-task.yaml)
if [ ! -z "${GITOPS_GIT_TOKEN}" ]; then
    DEV_SETUP_TASK=$(echo "${DEV_SETUP_TASK}" | yq ".spec.params[0].default = \"${GITOPS_GIT_TOKEN}\"" -M)
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi
    echo -n "."
fi
if [ ! -z "${GITHUB_APP_WEBHOOK_SECRET}" ]; then
    DEV_SETUP_TASK=$(echo "${DEV_SETUP_TASK}" | yq ".spec.params[2].default = \"${GITHUB_APP_WEBHOOK_SECRET}\"" -M)
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi
    echo -n "."
fi
if [ ! -z "${QUAY_DOCKERCONFIGJSON}" ]; then
    export QUAY_DOCKERCONFIGJSON=${QUAY_DOCKERCONFIGJSON}
    DEV_SETUP_TASK=$(echo "${DEV_SETUP_TASK}" | yq ".spec.params[3].default = strenv(QUAY_DOCKERCONFIGJSON)" -M)
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi
    echo -n "."
fi
export TASK_SCRIPT="#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SECRET_NAME=\"cosign-pub\"
if [ -n \"$COSIGN_SIGNING_PUBLIC_KEY\" ]; then
  echo -n \"* \$SECRET_NAME secret: \"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
data:
  cosign.pub: $COSIGN_SIGNING_PUBLIC_KEY
kind: Secret
metadata:
  labels:
    app.kubernetes.io/instance: default
    app.kubernetes.io/part-of: tekton-chains
    operator.tekton.dev/operand-name: tektoncd-chains
  name: \$SECRET_NAME
type: Opaque
EOF
  echo \"OK\"
fi

SECRET_NAME=\"gitops-auth-secret\"
if [ -n \"\$GIT_TOKEN\" ]; then
  echo -n \"* \$SECRET_NAME secret: \"
  kubectl create secret generic \"\$SECRET_NAME\" \\
    --from-literal=password=\$GIT_TOKEN \\
    --type=kubernetes.io/basic-auth \\
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
  echo \"OK\"
fi

SECRET_NAME=\"pipelines-secret\"
if [ -n \"\$PIPELINES_WEBHOOK_SECRET\" ]; then
  echo -n \"* \$SECRET_NAME secret: \"
  kubectl create secret generic \"\$SECRET_NAME\" \\
    --from-literal=webhook.secret=\$PIPELINES_WEBHOOK_SECRET \\
    --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
  echo \"OK\"
fi

SECRET_NAME=\"rhdh-image-registry-token\"
if [ -n \"\$QUAY_DOCKERCONFIGJSON\" ]; then
  echo -n \"* \$SECRET_NAME secret: \"
  DATA=\$(mktemp)
  echo -n \"\$QUAY_DOCKERCONFIGJSON\" >\"\$DATA\"
  kubectl create secret docker-registry \"\$SECRET_NAME\" \\
    --from-file=.dockerconfigjson=\"\$DATA\" --dry-run=client -o yaml | \\
    kubectl apply --filename - --overwrite=true >/dev/null
  rm \"\$DATA\"
  echo -n \".\"
  while ! kubectl get serviceaccount pipeline >/dev/null &>2; do
    sleep 2
    echo -n \"_\"
  done
  for SA in default pipeline; do
    kubectl patch serviceaccounts \"\$SA\" --patch \"
  secrets:
    - name: \$SECRET_NAME
  imagePullSecrets:
    - name: \$SECRET_NAME
  \" >/dev/null
    echo -n \".\"
  done
  echo \"OK\"
fi"
DEV_SETUP_TASK=$(echo "${DEV_SETUP_TASK}" | yq ".spec.steps[0].script = strenv(TASK_SCRIPT)" -M)
if [ $? -ne 0 ]; then
    echo -n "FAIL"
    exit 1
fi
echo -n "."
cat <<EOF | kubectl apply -n ${NAMESPACE} -f - >/dev/null
${DEV_SETUP_TASK}
EOF
if [ $? -ne 0 ]; then
    echo -n "FAIL"
    exit 1
fi
echo "OK"

# Configure Namespaces
# Configuring namespaces with needed resources
echo -n "* Configuring Namespaces: "
for NAMESPACE_SUFFIX in "development" "prod" "stage"; do
    APP_NAMESPACE="${NAMESPACE}-app-${NAMESPACE_SUFFIX}"

    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  labels:
    argocd.argoproj.io/managed-by: $NAMESPACE
  name: $APP_NAMESPACE
EOF
    if [ $? -ne 0 ]; then
        echo -n "FAIL"
        exit 1
    fi

    SECRET_NAME="cosign-pub"
    if [ -n "$COSIGN_SIGNING_PUBLIC_KEY" ]; then
        cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
data:
    cosign.pub: $COSIGN_SIGNING_PUBLIC_KEY
kind: Secret
metadata:
    labels:
        app.kubernetes.io/instance: default
        app.kubernetes.io/part-of: tekton-chains
        operator.tekton.dev/operand-name: tektoncd-chains
    name: $SECRET_NAME
    namespace: $APP_NAMESPACE
type: Opaque
EOF
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="gitops-auth-secret"
    if [ -n "$GITOPS_GIT_TOKEN" ]; then
        kubectl -n $APP_NAMESPACE create secret generic "$SECRET_NAME" \
            --from-literal=password=$GITOPS_GIT_TOKEN \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="pipelines-secret"
    if [ -n "$GITHUB_APP_WEBHOOK_SECRET" ]; then
        kubectl -n $APP_NAMESPACE create secret generic "$SECRET_NAME" \
            --from-literal=webhook.secret=$GITHUB_APP_WEBHOOK_SECRET \
            --dry-run=client -o yaml | kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        echo -n "."
    fi
    SECRET_NAME="rhdh-image-registry-token"
    if [ -n "$QUAY_DOCKERCONFIGJSON" ]; then
        DATA=$(mktemp)
        echo -n "$QUAY_DOCKERCONFIGJSON" >"$DATA"
        kubectl -n $APP_NAMESPACE create secret docker-registry "$SECRET_NAME" \
            --from-file=.dockerconfigjson="$DATA" --dry-run=client -o yaml | \
            kubectl -n $APP_NAMESPACE apply --filename - --overwrite=true >/dev/null
        if [ $? -ne 0 ]; then
            echo -n "FAIL"
            exit 1
        fi
        rm "$DATA"
        echo -n "."
        while ! kubectl -n $APP_NAMESPACE get serviceaccount pipeline >/dev/null; do
            sleep 2
            echo -n "_"
        done
        for SA in default pipeline; do
            kubectl -n $APP_NAMESPACE patch serviceaccounts "$SA" --patch "
        secrets:
        - name: $SECRET_NAME
        imagePullSecrets:
        - name: $SECRET_NAME
        " >/dev/null
            if [ $? -ne 0 ]; then
                echo -n "FAIL"
                exit 1
            fi
            echo -n "."
        done
        echo -n "."
    fi
done
echo "OK"