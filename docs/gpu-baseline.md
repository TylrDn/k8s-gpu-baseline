# GPU baseline walkthrough

End-to-end lifecycle for the manifests in this repository: discover GPU nodes,
confirm the device plugin advertises them, schedule a GPU pod, and verify
telemetry. Every command below is runnable as written; every manifest detail
quoted is from the files in `manifests/`.

- [0. Prerequisites](#0-prerequisites)
- [1. Apply the baseline](#1-apply-the-baseline)
- [2. Node discovery with NFD](#2-node-discovery-with-nfd)
- [3. Confirm nvidia.com/gpu is advertised](#3-confirm-nvidiacomgpu-is-advertised)
- [4. Schedule a GPU pod](#4-schedule-a-gpu-pod)
- [5. Verify DCGM exporter metrics](#5-verify-dcgm-exporter-metrics)
- [6. Verify metrics-server](#6-verify-metrics-server)
- [7. Run the smoke test](#7-run-the-smoke-test)
- [Troubleshooting](#troubleshooting)
- [Upstream documentation](#upstream-documentation)

## 0. Prerequisites

On the cluster nodes, before anything in this repository can work:

- NVIDIA drivers installed on every GPU node.
- A container runtime configured for NVIDIA, i.e. the NVIDIA Container Toolkit
  with the `nvidia` runtime wired into containerd/CRI-O. See the
  [NVIDIA Container Toolkit installation guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

On your workstation: `kubectl` (this repo is tested against v1.30.2, which
bundles Kustomize v5), plus `jq` and `curl` for the verification commands.

If you only want to check that the manifests are well formed, you do not need a
GPU at all — see [7. Run the smoke test](#7-run-the-smoke-test), which skips the
GPU-dependent checks on a CPU-only cluster.

## 1. Apply the baseline

```bash
kubectl apply -k kustomize/overlays/prod   # or: make deploy-baseline
```

Local KIND cluster (adds `--kubelet-insecure-tls` to metrics-server, because
KIND kubelets serve metrics with a self-signed certificate):

```bash
make kind-up
kubectl apply -k kustomize/overlays/dev    # or: make deploy-dev
```

What lands, per `kubectl kustomize kustomize/overlays/prod` (16 objects):

| Namespace | Object | Image |
|-----------|--------|-------|
| `kube-system` | DaemonSet `nvidia-device-plugin-daemonset` | `nvcr.io/nvidia/k8s-device-plugin:v0.14.5` |
| `node-feature-discovery` | ServiceAccount + DaemonSet `nfd-worker` | `registry.k8s.io/nfd/node-feature-discovery:v0.14.0` |
| `gpu-telemetry` | ServiceAccount + DaemonSet + Service `dcgm-exporter` (9400) | `nvcr.io/nvidia/k8s/dcgm-exporter:3.1.8-2.6.7-ubuntu20.04` |
| `metrics-server` | Deployment + Service `metrics-server` (443 → 4443) | `registry.k8s.io/metrics-server/metrics-server:v0.6.4` |
| `ingress-nginx` | Deployment `ingress-nginx-controller` + Service (LoadBalancer, 80) | `registry.k8s.io/ingress-nginx/controller:v1.9.4` |
| `default` | NetworkPolicies `default-deny-all`, `allow-dns-egress` | – |

Check rollout:

```bash
kubectl -n kube-system rollout status ds/nvidia-device-plugin-daemonset
kubectl -n gpu-telemetry rollout status ds/dcgm-exporter
kubectl -n metrics-server rollout status deploy/metrics-server
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller
```

> **Read this before trusting the baseline in production.** The manifests are
> intentionally minimal and several components are shipped without the RBAC and
> API registration their upstream charts install. See
> [Known gaps](../README.md#known-gaps) in the README. In particular
> metrics-server here has no `APIService` object, so `kubectl top` will not work
> until you add one.

## 2. Node discovery with NFD

`manifests/node-feature-discovery.yaml` deploys the `nfd-worker` DaemonSet in
the `node-feature-discovery` namespace with its own ServiceAccount. The worker
inspects each node's hardware — including PCI vendor `0x10de` (NVIDIA) — and
reports it so that nodes can be labelled `feature.node.kubernetes.io/...`.

```bash
kubectl -n node-feature-discovery get ds nfd-worker -o wide
kubectl -n node-feature-discovery logs -l app=nfd-worker --tail=50

# NFD-generated labels, if a master is running to apply them:
kubectl get nodes -o json |
  jq '.items[] | {name: .metadata.name,
                  nfd: (.metadata.labels | with_entries(
                        select(.key | startswith("feature.node.kubernetes.io"))))}'

# NVIDIA PCI device present on the node:
kubectl get nodes -l feature.node.kubernetes.io/pci-10de.present=true
```

If that last command returns nothing, see the
[troubleshooting table](#troubleshooting): this repository ships the worker
only, not `nfd-master`, and the worker cannot label nodes on its own.

You can also label GPU nodes yourself, which is enough for scheduling:

```bash
kubectl label node <node> nvidia.com/gpu.present=true
```

## 3. Confirm `nvidia.com/gpu` is advertised

The device plugin (`manifests/nvidia-device-plugin.yaml`) runs in `kube-system`
as a privileged container with a `nvidia.com/gpu: Exists` `NoSchedule`
toleration and `--fail-on-init-error=false`, so it starts even on nodes without
a GPU instead of crash-looping. When it succeeds, kubelet advertises the
extended resource:

```bash
kubectl get nodes -o json | jq '.items[].status.allocatable'
```

Look for `"nvidia.com/gpu": "1"` (or higher). Per-node view:

```bash
kubectl get nodes -o custom-columns=\
'NODE:.metadata.name,GPU_ALLOCATABLE:.status.allocatable.nvidia\.com/gpu'
```

Plugin logs:

```bash
kubectl -n kube-system logs -l app=nvidia-device-plugin --tail=50
```

A healthy start logs that it found devices and registered with kubelet. Note
that `--fail-on-init-error=false` means an *unhealthy* start is quiet: the pod
stays Running while advertising nothing. Always confirm with the allocatable
check above rather than with pod status.

## 4. Schedule a GPU pod

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-check
spec:
  restartPolicy: Never
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: nvidia-smi
      image: nvidia/cuda:12.2.0-base-ubuntu22.04
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gpu-check --timeout=300s
kubectl logs gpu-check
kubectl delete pod gpu-check
```

`nvidia.com/gpu` must be requested as a **limit**; GPUs cannot be
overcommitted or fractionally requested by the stock device plugin. If the pod
stays `Pending`, `kubectl describe pod gpu-check` will say
`0/N nodes are available: N Insufficient nvidia.com/gpu`.

## 5. Verify DCGM exporter metrics

`manifests/dcgm-exporter.yaml` runs the exporter as a DaemonSet in
`gpu-telemetry` and fronts it with a ClusterIP Service on port 9400.

```bash
kubectl -n gpu-telemetry port-forward svc/dcgm-exporter 9400:9400 &
curl -s http://127.0.0.1:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
kill %1
```

Expected shape (one series per GPU; values vary):

```
# HELP DCGM_FI_DEV_GPU_UTIL GPU utilization (in %).
# TYPE DCGM_FI_DEV_GPU_UTIL gauge
DCGM_FI_DEV_GPU_UTIL{gpu="0",UUID="GPU-...",device="nvidia0",...} 0
```

Other useful series exposed by the same endpoint include
`DCGM_FI_DEV_FB_USED` (framebuffer memory used, MiB),
`DCGM_FI_DEV_GPU_TEMP` (°C) and `DCGM_FI_DEV_POWER_USAGE` (W). The full field
list is in the
[DCGM exporter documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html).

**Prometheus.** This repository does not deploy Prometheus and contains no
`ServiceMonitor` or `PodMonitor`. To scrape the exporter, point your existing
Prometheus at `dcgm-exporter.gpu-telemetry.svc:9400` — with kube-prometheus-stack
that means adding a `ServiceMonitor` selecting `app: dcgm-exporter` in the
`gpu-telemetry` namespace. Remember the NetworkPolicy posture
([networking-and-security.md](networking-and-security.md)) if Prometheus lives
in a namespace that must be allowed to reach it.

## 6. Verify metrics-server

```bash
kubectl top nodes
kubectl top pods -A
```

`kubectl top` reads the `metrics.k8s.io` API. As shipped, this repository
deploys only the metrics-server Deployment and Service — **not** the
`v1beta1.metrics.k8s.io` APIService, ServiceAccount or RBAC that upstream's
`components.yaml` includes — so `kubectl top` will report
`error: Metrics API not available` until you add them. Check what is running
with:

```bash
kubectl -n metrics-server get deploy,svc,pods
kubectl -n metrics-server logs deploy/metrics-server --tail=50
kubectl get apiservices | grep metrics    # empty in a stock install of this repo
```

On a local cluster with self-signed kubelet certificates, use the dev overlay
(`--kubelet-insecure-tls`) or metrics-server logs
`x509: cannot validate certificate ... because it doesn't contain any IP SANs`.

## 7. Run the smoke test

```bash
make smoke          # equivalent to ./scripts/smoke.sh
./scripts/smoke.sh --timeout 600 --keep
```

Checks performed, in order: cluster reachability → allocatable `nvidia.com/gpu`
→ `nvidia-smi` Job → DCGM `DCGM_FI_DEV_GPU_UTIL` scrape → Ready ingress-nginx
controller pod.

Expected output on a GPU cluster with the baseline applied:

```
PASS  cluster reachable: my-gpu-cluster
PASS  allocatable nvidia.com/gpu across nodes: 4
PASS  nvidia-smi Job completed
      +-----------------------------------------------------------------------+
      | NVIDIA-SMI 535.xx       Driver Version: 535.xx    CUDA Version: 12.2   |
      ...
PASS  DCGM exporter serves DCGM_FI_DEV_GPU_UTIL
      DCGM_FI_DEV_GPU_UTIL{gpu="0",...} 0
PASS  ingress-nginx controller pod is Ready

smoke: all executed checks passed, 0 skipped
```

On a KIND / CPU-only cluster the GPU checks are skipped, not failed:

```
PASS  cluster reachable: kind-kind
SKIP  no allocatable nvidia.com/gpu on any node
      Expected on a KIND or other CPU-only cluster. ...
SKIP  nvidia-smi Job (no GPUs)
SKIP  DCGM exporter scrape (no GPUs)
```

Failure modes and exit codes:

| Situation | Output | Exit |
|-----------|--------|------|
| `kubectl` missing, or no reachable cluster | `cannot reach a Kubernetes cluster ...` | `2` |
| No GPUs on any node | three `SKIP` lines, remaining checks still run | `0` if nothing else fails |
| `nvidia-smi` Job never completes | `FAIL ... did not complete within Ns` plus Job events and pod logs | `1` |
| DCGM Service missing | `FAIL service dcgm-exporter not found in namespace gpu-telemetry` | `1` |
| DCGM answers but has no GPU-util series | `FAIL ... exposes no DCGM_FI_DEV_GPU_UTIL series` | `1` |
| Ingress controller not Ready | `FAIL no Ready ingress-nginx controller pod ...` plus `kubectl get pods` output | `1` |

The script deletes its Job and kills its port-forward on exit; pass `--keep` to
leave the Job in place for inspection.

## Troubleshooting

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| `nvidia.com/gpu` absent from `status.allocatable` | Device plugin never registered — usually a missing NVIDIA driver or a container runtime without the NVIDIA runtime configured | `kubectl -n kube-system logs -l app=nvidia-device-plugin`; verify `nvidia-smi` on the node itself; install/configure the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |
| Device plugin pod is Running but advertises nothing | `--fail-on-init-error=false` suppresses the init failure | Read the plugin logs; remove the flag temporarily to make the failure loud |
| No `feature.node.kubernetes.io/*` labels | This repo deploys only `nfd-worker`; upstream NFD also needs `nfd-master` (and RBAC) to write labels | Install NFD from [upstream](https://kubernetes-sigs.github.io/node-feature-discovery/stable/deployment/kustomize.html), or label GPU nodes manually |
| GPU pod stuck `Pending` | No allocatable GPU, or a taint the pod does not tolerate | `kubectl describe pod` and read the scheduling events; add the `nvidia.com/gpu` `NoSchedule` toleration |
| GPU pod `Pending` with `Insufficient nvidia.com/gpu` while GPUs exist | All GPUs already claimed — a GPU cannot be shared by default | Free a workload, or look at time-slicing / MPS / MIG in the [device plugin docs](https://github.com/NVIDIA/k8s-device-plugin) |
| `curl` to the exporter fails / connection refused | DCGM pod not Ready, or the port-forward targeted the wrong namespace | `kubectl -n gpu-telemetry get pods -o wide`; `kubectl -n gpu-telemetry logs ds/dcgm-exporter` |
| Metrics returned but no `DCGM_FI_DEV_GPU_UTIL` | Exporter started without access to a GPU | Check the exporter is scheduled on a GPU node and the NVIDIA runtime is in use |
| `kubectl top nodes` → `Metrics API not available` | The `v1beta1.metrics.k8s.io` APIService is not part of this repository | Apply the APIService + RBAC from [metrics-server upstream](https://github.com/kubernetes-sigs/metrics-server) |
| metrics-server logs `x509 ... doesn't contain any IP SANs` | Self-signed kubelet certificates | Use the dev overlay, which patches in `--kubelet-insecure-tls` |
| Ingress controller CrashLoopBackOff | The controller needs a ServiceAccount, RBAC and an IngressClass, none of which are in this repo | Install the [upstream ingress-nginx deploy manifest](https://kubernetes.github.io/ingress-nginx/deploy/) alongside or instead of `manifests/ingress-nginx.yaml` |
| Pods cannot reach anything | `default-deny-all` NetworkPolicy in the `default` namespace | See [networking-and-security.md](networking-and-security.md) |
| `kubectl kustomize` warns about `patchesStrategicMerge` | Old checkout | Update; the overlays use `patches:` |

## Upstream documentation

- [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
  — the fuller, opinionated alternative to hand-rolled manifests like these
- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Node Feature Discovery](https://kubernetes-sigs.github.io/node-feature-discovery/stable/get-started/index.html)
- [DCGM exporter](https://github.com/NVIDIA/dcgm-exporter)
- [Kubernetes metrics-server](https://github.com/kubernetes-sigs/metrics-server)
- [Kubernetes: schedule GPUs](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)
- [ingress-nginx installation guide](https://kubernetes.github.io/ingress-nginx/deploy/)
