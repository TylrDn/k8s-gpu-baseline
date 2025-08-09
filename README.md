# k8s-gpu-baseline

Minimal Day-0/1 GPU-ready Kubernetes baseline for demos and interviews. It deploys key NVIDIA components and guardrails so you can stand up a cluster quickly, smoke it locally with KIND (CPU-only), and later expand on a real GPU fleet.

## Requirements

* `kubectl`
* `docker`
* `kind`
* `make`
* GPU cluster optional

## TL;DR

```bash
make kind-up
make deploy-baseline
make deploy-netpol
make smoke
```

## What gets deployed

* **metrics-server** – CPU/memory metrics for HPA and dashboards
* **ingress-nginx** – community ingress controller with sample `/healthz`
* **Node Feature Discovery (NFD)** – labels nodes with hardware features (e.g. GPUs)
* **NVIDIA device plugin** – advertises GPUs to the scheduler
* **DCGM exporter** – GPU metrics on port 9400 with a Grafana dashboard stub
* **NetworkPolicies** – default deny with explicit egress for core services

## Kustomize

```bash
make kustomize-dev | kubectl apply -f -
make kustomize-prod | kubectl apply -f -
```

## Observability

Port-forward DCGM exporter and view metrics:

```bash
kubectl -n gpu-metrics port-forward ds/dcgm-exporter 9400:9400
curl localhost:9400/metrics
```

Import `dashboards/dcgm-overview.json` into Grafana for a starter dashboard.

## Ingress smoke

```bash
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
curl localhost:8080/healthz
```

Or on KIND, curl the NodePort `http://localhost:30080/healthz`.

## GPU smoke

`scripts/smoke-test.sh` looks for GPU nodes and, if found, runs a CUDA pod that executes `nvidia-smi`. On CPU-only clusters it prints a friendly message and exits.

## Security posture

Namespaces ship with default-deny `NetworkPolicy` objects and explicit allows for DNS, time sync, registry access, and Prometheus scraping. These policies are examples—adjust CIDRs and selectors for your environment.

## Troubleshooting

* **Device plugin Pending** – expected on clusters without GPUs
* **metrics-server TLS** – the Deployment uses `--kubelet-insecure-tls` for local labs
* **KIND NodePort access** – ports 30000–30090 are forwarded by the KIND config
* **CNI conflicts** – ensure your cluster CNI supports `NetworkPolicy`

## Cleanup

```bash
make teardown
```

## License

Apache-2.0. See [LICENSE](LICENSE).

## Contributions

Issues and PRs welcome. This repo is a starting point—tailor it to your needs.
