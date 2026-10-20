# Setting Up caData for K8s API Server TLS Communication

## Background

When configuring a Backstage plugin (or any external client) to talk to a Kubernetes/OpenShift API server with TLS verification enabled, you need the CA certificate that signed the API server's **external serving certificate**. This is not necessarily the same CA mounted inside pods at `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt` — that CA is for internal pod-to-API-server communication within the cluster.

The `@kubernetes/client-node` library expects `caData` to be **base64-encoded PEM** (same format as `certificate-authority-data` in kubeconfig files). It internally does `Buffer.from(caData, 'base64')` to decode it.

## ROSA Clusters with Let's Encrypt

ROSA (Red Hat OpenShift on AWS) clusters often have the API server configured with publicly-trusted Let's Encrypt certificates. In this case:

- The API server presents a cert chain: `*.redhat-ai-dev...` -> `Let's Encrypt YR2` -> `ISRG Root YR` -> `ISRG Root X1`
- Node.js's default CA trust store already includes the ISRG root
- **You do not need `caData` at all** — just set `skipTLSVerify: false` and omit `caData`
- The pod's `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt` contains the **OpenShift internal root CA** (`OU=openshift, CN=root-ca`), which is for internal cluster TLS, not for the external API endpoint

You can verify this with:

```bash
# Check what CA the API server presents externally:
echo | openssl s_client -connect api.my-cluster.example.com:443 -showcerts 2>/dev/null \
  | openssl x509 -noout -issuer -subject

# If issuer shows Let's Encrypt / ISRG, no caData needed.

# Also confirm kubeconfig has no certificate-authority-data for this cluster:
oc config view --raw -o jsonpath='{.clusters[?(@.name=="<cluster-name>")].cluster.certificate-authority-data}'
# Empty result = system trust store is sufficient.
```

## Non-Let's Encrypt Clusters (Self-Signed / Internal CA)

For clusters where the API server uses a self-signed or internally-signed certificate, you need to provide the CA. Four approaches:

### 1. From kubeconfig (easiest if you can `oc login`)

```bash
oc login https://api.my-cluster.example.com:6443
# Then extract the CA it saved (already base64-encoded, ready for caData):
oc config view --raw \
  -o jsonpath='{.clusters[?(@.name=="<cluster-name>")].cluster.certificate-authority-data}'
```

### 2. From the cluster's configmap (if already logged in)

```bash
# OpenShift stores the API server CA here:
oc get configmap kube-root-ca.crt -n openshift-config \
  -o jsonpath='{.data.ca\.crt}' | base64 -w0
```

### 3. From openssl (if you just have network access)

```bash
# Grab the full cert chain the API server presents:
echo | openssl s_client -connect api.my-cluster.example.com:6443 -showcerts 2>/dev/null \
  | awk '/BEGIN CERT/,/END CERT/' | base64 -w0
```

To extract just the root CA (last cert in the chain), use:

```bash
echo | openssl s_client -connect api.my-cluster.example.com:6443 -showcerts 2>/dev/null \
  | awk '/BEGIN CERT/,/END CERT/' | awk 'BEGIN{n=0} /BEGIN CERT/{n++; cert=""} {cert=cert $0 "\n"} /END CERT/{last=cert}END{printf "%s", last}' \
  | base64 -w0
```

### 4. From the cluster admin

Ask the admin who set up the API server certs — they'll have the CA that signed the serving cert.

## Quick Identification of Certificate Subjects

You can identify a PEM certificate's subject by reading the base64 text between `BEGIN CERTIFICATE` and `END CERTIFICATE`. Common CA names are readable as ASCII within the base64 encoding:

- `b3BlbnNoaWZ0` = `openshift` (OpenShift internal root CA)
- `TGV0J3MgRW5jcnlwdA` = `Let's Encrypt`
- `SVNSR` = `ISRG` (Internet Security Research Group)

Or decode properly:

```bash
# Decode a PEM cert to see its subject and issuer:
openssl x509 -noout -subject -issuer <<< "$(cat cert.pem)"
```

## app-config.yaml Examples

### Cluster with publicly-trusted cert (e.g., ROSA with Let's Encrypt)

```yaml
cluster-1:
  name: my-rosa-cluster
  url: '${K8S_CLUSTER_URL}'
  serviceAccountToken: '${K8S_SA_TOKEN}'
  skipTLSVerify: false
  # caData not needed — API server uses publicly-trusted cert
```

### Cluster with self-signed / internal CA

```yaml
cluster-1:
  name: my-internal-cluster
  url: '${K8S_CLUSTER_URL}'
  serviceAccountToken: '${K8S_SA_TOKEN}'
  skipTLSVerify: false
  caData: '${K8S_CA_DATA}'  # base64-encoded PEM from one of the methods above
```

### Local dev (skip TLS verification)

```yaml
cluster-1:
  name: my-dev-cluster
  url: '${K8S_CLUSTER_URL}'
  serviceAccountToken: '${K8S_SA_TOKEN}'
  skipTLSVerify: true
  # No caData needed when skipping TLS verification
```

**Note:** `skipTLSVerify` only covers `@kubernetes/client-node` calls (informer,
K8s API). Code that uses Node.js `fetch()` directly (e.g. `fetchModelCard`
calling the Kubeflow catalog route) has its own TLS validation and ignores
`skipTLSVerify`. To disable TLS verification for *all* Node.js HTTPS calls,
set `NODE_TLS_REJECT_UNAUTHORIZED=0`. Prefer `NODE_EXTRA_CA_CERTS` pointing
at the CA PEM bundle instead — it keeps TLS verification active.
