# Setup Instructions

This guide walks through standing up the **k8s-gpu-baseline** project from scratch.
It covers installing dependencies, bootstrapping a local [KIND](https://kind.sigs.k8s.io/) cluster, deploying core components, and running smoke tests.

## 1. Install Requirements

The project expects the following tools on your machine:

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io/)
- [make](https://www.gnu.org/software/make/)

You can install the Kubernetes-specific tools automatically:

```bash
make deps
```

> **Note:** `make deps` installs binaries into `/usr/local/bin` by default. Use `BIN_DIR=/custom/path make deps` to specify a different location.

## 2. Create a KIND Cluster

```bash
make kind-up
```

This generates a cluster configuration and spins up a local Kubernetes cluster.

## 3. Deploy GPU Baseline Components

```bash
make deploy-baseline
```

The command applies manifests for:

- `metrics-server`
- `ingress-nginx`
- `Node Feature Discovery`
- `NVIDIA device plugin`
- `DCGM exporter`

## 4. Apply Example NetworkPolicies

```bash
make deploy-netpol
```

Sample `NetworkPolicy` objects provide a default-deny posture with explicit egress rules for core services.

## 5. Run Smoke Tests

```bash
make smoke
```

The smoke test checks for GPU nodes and, if available, launches a CUDA container that executes `nvidia-smi`.

## 6. Tear Down the Cluster

When finished, delete the KIND cluster:

```bash
make teardown
```

## Next Steps

Explore the [kustomize overlays](kustomize/overlays) for dev and prod environments or import the Grafana dashboard found under `dashboards/` to visualize GPU metrics.
