# KServe connector client TLS helpers

Original QE attachments from [RHIDP-14261](https://redhat.atlassian.net/browse/RHIDP-14261):

| File | Purpose |
| --- | --- |
| `OCP-SET-UP-CLIENT-TLS.md` | When `caData` is required vs ROSA/Let's Encrypt |
| `extract-ca-from-kubeconfig.sh` | Pull base64 CA bundle from a kubeconfig cluster entry |
| `set-ca-env.sh` | Export `K8S_CA_DATA` / `NODE_EXTRA_CA_CERTS` for install + local clients |

## Use with this GitOps install

```bash
# 1. Extract CA for a non–publicly-trusted API server
./tests/fixtures/kserve/tls/extract-ca-from-kubeconfig.sh "$KUBECONFIG" [cluster-name]

# 2. Export into the shell (then copy into scripts/private-env if desired)
export KUBECONFIG=...
source ./tests/fixtures/kserve/tls/set-ca-env.sh

# 3. Install / reconcile so kserve-connector-secrets gets K8S_CA_DATA
#    (setup-secrets.sh / reconcile-kserve-secrets.sh already wire caData)
make install-kserve-catalog-bridge-rhoai-handled-separately
```

On ROSA with Let's Encrypt, leave `K8S_CA_DATA` empty and keep `skipTLSVerify: false`
(see `OCP-SET-UP-CLIENT-TLS.md`).
