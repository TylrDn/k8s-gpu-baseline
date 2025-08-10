# k8s-gpu-baseline

A minimal, production-leaning Kubernetes baseline for GPU workloads. It
installs the NVIDIA device plugin, Node Feature Discovery, DCGM exporter,
metrics server and ingress controller with secure defaults such as RBAC and
NetworkPolicies.

## Repository layout
```
  README.md
  Makefile
  helmfile.yaml
  charts/
  kustomize/
  manifests/
  tools/
  .github/workflows/ci.yaml
  .pre-commit-config.yaml
  LICENSE
```

## Prerequisites
- `kubectl`
- `helm`
- `docker`
- `kind` (for local testing)

## Quickstart (local KIND)
```bash
make kind-up
make deploy-baseline
make smoke
```

## Quickstart (any GPU cluster)
```bash
kubectl apply -f manifests/nvidia-device-plugin.yaml
kubectl apply -f manifests/node-feature-discovery.yaml
kubectl apply -f manifests/dcgm-exporter.yaml
kubectl apply -f manifests/metrics-server.yaml
kubectl apply -f manifests/ingress-nginx.yaml
kubectl apply -k kustomize/overlays/prod
```

## Make targets
| Target | Description |
|--------|-------------|
| `kind-up` | Create a local KIND cluster |
| `deploy-baseline` | Install NVIDIA plugin, NFD, DCGM, metrics, ingress |
| `smoke` | Run GPU detection job and curl ingress health |
| `teardown` | Delete cluster/resources |

## CI
GitHub Actions runs `kubeconform` on the Kustomize overlay and linters via
`pre-commit`.
