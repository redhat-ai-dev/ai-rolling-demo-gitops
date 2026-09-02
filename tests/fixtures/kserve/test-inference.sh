#!/usr/bin/env bash
# Sends a V2 inference request to the sklearn-iris predictor in-cluster.
set -euo pipefail

NAMESPACE="${1:-ggmtest}"
SERVICE_NAME="sklearn-iris"
URL="http://${SERVICE_NAME}-predictor.${NAMESPACE}.svc.cluster.local:8080/v2/models/${SERVICE_NAME}/infer"

kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -n "$NAMESPACE" -- \
  curl -sS -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{"inputs": [{"name": "input-0", "shape": [2, 4], "datatype": "FP32", "data": [[6.8, 2.8, 4.8, 1.4], [6.0, 3.4, 4.5, 1.6]]}]}'
