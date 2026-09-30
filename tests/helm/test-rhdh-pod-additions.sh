#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rendered="$(mktemp)"
ci_rendered="$(mktemp)"
trap 'rm -f "$rendered" "$ci_rendered"' EXIT

helm template rhdhai-rhdh-dev "$repo_root/charts/rhdh" \
  --namespace rhdhai-development > "$rendered"

yq -o=json '.' "$rendered" | jq -s -e '
  [.[] | select(.kind == "Deployment" and .metadata.name == "rhdhai-rhdh-dev-backstage")]
  | length == 1 and
    (.[0].spec.template.spec as $pod |
      ($pod.volumes | any(.name == "lightspeed-skills" and .emptyDir == {})) and
      ($pod.volumes | any(.name == "gcp-creds" and .secret.secretName == "llama-stack-secrets")) and
      ($pod.initContainers | any(
        .name == "fetch-lightspeed-skills" and
        .image == "quay.io/redhat-ai-dev/utils:latest" and
        (.args[0] | contains("https://github.com/redhat-developer/rhdh-skills.git")) and
        (.volumeMounts | any(.name == "lightspeed-skills" and .mountPath == "/skills")) and
        .securityContext.readOnlyRootFilesystem == true and
        .securityContext.allowPrivilegeEscalation == false and
        .resources.requests.cpu == "25m" and
        .resources.limits.memory == "128Mi"
      )) and
      ($pod.containers | any(
        .name == "lightspeed-core" and
        (.volumeMounts | any(.name == "lightspeed-skills" and .mountPath == "/app-root/skills")) and
        (.volumeMounts | any(.name == "gcp-creds" and .mountPath == "/app-root/gcp-creds.json" and .subPath == "gcp-creds.json" and .readOnly == true)) and
        (.env | any(.name == "GOOGLE_APPLICATION_CREDENTIALS" and .value == "/app-root/gcp-creds.json"))
      )) and
      ($pod.containers | any(
        .name == "feedback-harvester" and
        .image == "quay.io/redhat-ai-dev/feedback-harvester:v0.1.0" and
        (.volumeMounts | any(.name == "lightspeed-data" and .mountPath == "/tmp/data/feedback" and .subPath == "data/feedback")) and
        (.env | any(.name == "PGUSER" and .valueFrom.secretKeyRef.name == "lightspeed-postgres-info" and .valueFrom.secretKeyRef.key == "user")) and
        (.env | any(.name == "PGPASSWORD" and .valueFrom.secretKeyRef.name == "lightspeed-postgres-info" and .valueFrom.secretKeyRef.key == "password")) and
        (.env | any(.name == "PGDATABASE" and .valueFrom.secretKeyRef.name == "lightspeed-postgres-info" and .valueFrom.secretKeyRef.key == "db-name")) and
        (.env | any(.name == "PGHOST" and .value == "lightspeed-postgres-svc.lightspeed-postgres.svc.cluster.local")) and
        (.env | any(.name == "PGPORT" and .value == "5432")) and
        (.env | any(.name == "FEEDBACK_DIRECTORY" and .value == "/tmp/data/feedback")) and
        (.env | any(.name == "FETCH_FREQUENCY" and .value == "60"))
      ))
    )
' > /dev/null

yq -o=json '.' "$rendered" | jq -s -e '
  all(.[];
    .kind != "Job" or .metadata.name != "update-deployment-containers"
  ) and
  all(.[];
    (.kind != "Role" and .kind != "RoleBinding") or
    (.metadata.name | startswith("sidecars-job-deployment-patcher") | not)
  ) and
  any(.[];
    .kind == "ClusterRoleBinding" and .metadata.name == "cluster-reader-binding"
  )
' > /dev/null

yq -e '
  select(.kind == "ConfigMap" and .metadata.name == "lightspeed-stack-config")
  | .data."lightspeed-stack.yaml"
  | from_yaml
  | .skills.paths[]
  | select(. == "/app-root/skills")
' "$rendered" > /dev/null

helm template rhdh-ci "$repo_root/charts/rhdh" \
  --namespace rolling-demo-ns -f "$repo_root/ci/values-ci.yaml" > "$ci_rendered"
yq -o=json '.' "$ci_rendered" | jq -s -e '
  [.[] | select(.kind == "Deployment" and .metadata.name == "rhdh-ci-backstage")]
  | length == 1 and
    (.[0].spec.template.spec.containers | any(.name == "feedback-harvester"))
' > /dev/null

echo "Chart-managed RHDH pod additions render without the patch Job"
