# k8s-gpu-baseline

A minimal, production-leaning Kubernetes baseline for GPU workloads. It
installs the NVIDIA device plugin, Node Feature Discovery, DCGM exporter,
metrics server and ingress controller with secure defaults such as RBAC and
NetworkPolicies.

## Repository layout
```
  README.md
  Makefile
  kustomize/
  manifests/
  tools/
  .github/workflows/ci.yaml
  .pre-commit-config.yaml
  LICENSE
```

## Prerequisites
- `kubectl` (v1.21+ with Kustomize support)
- `docker` and `kind` (for local testing)

## Quickstart

### Local KIND
```bash
make kind-up
kubectl apply -k kustomize/overlays/dev
make smoke
```

### Any GPU cluster
```bash
kubectl apply -k kustomize/overlays/prod
```

## Make targets
| Target | Description |
|--------|-------------|
| `kind-up` | Create a local KIND cluster |
| `deploy-baseline` | Install GPU baseline manifests via Kustomize |
| `smoke` | Run GPU detection job and curl ingress health |
| `teardown` | Delete cluster/resources |

## Testing
Ensure the pinned tool versions are installed:

```bash
kubectl version --client --short | grep v1.30.2
kubeconform -v # v0.6.4
```

Run linters and schema checks:

```bash
pre-commit run --files $(git ls-files '*.yaml' '*.yml' '*.md' 'Makefile')
kubectl kustomize kustomize/overlays/prod | kubeconform -strict -
```

## CI
GitHub Actions runs `kubeconform` on the Kustomize overlay and linters via
`pre-commit`.
