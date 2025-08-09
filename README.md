# k8s-gpu-baseline

**What this is**  
A clean, production-leaning GPU Kubernetes baseline: NVIDIA device plugin, Node Feature Discovery (NFD), DCGM exporter, metrics-server, ingress, and default-deny NetworkPolicies. Includes KIND for local smoke tests, Kustomize/Helm overlays, a Makefile, and CI linting.

**Why it matters**  
Demonstrates day-0/1 cluster enablement for GPU workloads: scheduling, observability, and secure defaults—what an HPC/AI/ML Solutions Architect sets up before training/inference lands.

## Quickstart (local KIND)
```bash
make kind-up
make deploy-baseline
make smoke
```

Quickstart (GPU cluster)

kubectl apply -f manifests/nvidia-device-plugin.yaml
kubectl apply -f manifests/node-feature-discovery.yaml
kubectl apply -f manifests/dcgm-exporter.yaml
kubectl apply -f manifests/metrics-server.yaml
kubectl apply -f manifests/ingress-nginx.yaml
kubectl apply -k kustomize/overlays/prod
