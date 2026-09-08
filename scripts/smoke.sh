#!/usr/bin/env bash
#
# Smoke test for the k8s-gpu-baseline.
#
# Checks, in order:
#   1. the cluster is reachable
#   2. at least one node advertises allocatable nvidia.com/gpu
#      (SKIPs the GPU-dependent checks instead of failing on a CPU-only
#      cluster such as KIND)
#   3. an nvidia-smi Job runs to completion on a GPU node
#   4. the DCGM exporter serves DCGM_FI_DEV_GPU_UTIL
#   5. the ingress-nginx controller pod is Ready
#
# Exit codes: 0 all executed checks passed, 1 at least one check failed,
#             2 the cluster is unreachable or kubectl is missing.
#
# Usage: scripts/smoke.sh [--timeout SECONDS] [--keep]
set -euo pipefail

TIMEOUT="${SMOKE_TIMEOUT:-300}"
KEEP=0
JOB_NAME="gpu-smoke-nvidia-smi"
JOB_NS="${SMOKE_NAMESPACE:-default}"
CUDA_IMAGE="${SMOKE_CUDA_IMAGE:-nvidia/cuda:12.2.0-base-ubuntu22.04}"
DCGM_NS="gpu-telemetry"
DCGM_SVC="dcgm-exporter"
DCGM_PORT=9400
INGRESS_NS="ingress-nginx"
INGRESS_SELECTOR="app=ingress-nginx"

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

FAILURES=0
SKIPS=0

pass() { printf 'PASS  %s\n' "$1"; }
skip() { printf 'SKIP  %s\n' "$1"; SKIPS=$((SKIPS + 1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }
info() { printf '      %s\n' "$1"; }

cleanup() {
  if [ "$KEEP" -eq 0 ]; then
    kubectl delete job "$JOB_NAME" -n "$JOB_NS" --ignore-not-found \
      --wait=false >/dev/null 2>&1 || true
  fi
  if [ -n "${PF_PID:-}" ]; then
    kill "$PF_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------- 1. cluster
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found on PATH" >&2
  exit 2
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "cannot reach a Kubernetes cluster (check your kubeconfig context)" >&2
  exit 2
fi
pass "cluster reachable: $(kubectl config current-context)"

# ------------------------------------------------------------ 2. GPU capacity
gpu_total="$(
  kubectl get nodes \
    -o jsonpath='{range .items[*]}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}' |
    awk '{ s += $1 } END { print s + 0 }'
)"

GPUS_PRESENT=0
if [ "$gpu_total" -gt 0 ]; then
  GPUS_PRESENT=1
  pass "allocatable nvidia.com/gpu across nodes: $gpu_total"
else
  skip "no allocatable nvidia.com/gpu on any node"
  info "Expected on a KIND or other CPU-only cluster. The nvidia-smi Job and"
  info "the DCGM exporter scrape below are skipped; the manifests can still be"
  info "applied and the non-GPU checks still run."
fi

# ------------------------------------------------------------ 3. nvidia-smi Job
if [ "$GPUS_PRESENT" -eq 1 ]; then
  kubectl delete job "$JOB_NAME" -n "$JOB_NS" --ignore-not-found >/dev/null 2>&1
  if kubectl apply -n "$JOB_NS" -f - >/dev/null <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: nvidia-smi
          image: ${CUDA_IMAGE}
          command: ["nvidia-smi"]
          resources:
            limits:
              nvidia.com/gpu: 1
EOF
  then
    if kubectl wait --for=condition=complete "job/${JOB_NAME}" \
      -n "$JOB_NS" --timeout="${TIMEOUT}s" >/dev/null 2>&1; then
      pass "nvidia-smi Job completed"
      kubectl logs -n "$JOB_NS" "job/${JOB_NAME}" 2>/dev/null |
        sed -n '1,12p' | sed 's/^/      /'
    else
      fail "nvidia-smi Job did not complete within ${TIMEOUT}s"
      kubectl describe job "$JOB_NAME" -n "$JOB_NS" 2>&1 |
        sed -n '/Events/,$p' | sed 's/^/      /' || true
      kubectl logs -n "$JOB_NS" "job/${JOB_NAME}" --tail=20 2>&1 |
        sed 's/^/      /' || true
    fi
  else
    fail "could not create the nvidia-smi Job in namespace ${JOB_NS}"
  fi
else
  skip "nvidia-smi Job (no GPUs)"
fi

# ---------------------------------------------------------- 4. DCGM exporter
if [ "$GPUS_PRESENT" -eq 1 ]; then
  if kubectl get service "$DCGM_SVC" -n "$DCGM_NS" >/dev/null 2>&1; then
    local_port=0
    for candidate in 19400 19401 19402; do
      if ! (exec 3<>"/dev/tcp/127.0.0.1/${candidate}") 2>/dev/null; then
        local_port="$candidate"
        break
      fi
      exec 3<&- 2>/dev/null || true
    done
    if [ "$local_port" -eq 0 ]; then
      fail "no free local port for the DCGM port-forward"
    else
      kubectl port-forward -n "$DCGM_NS" "svc/${DCGM_SVC}" \
        "${local_port}:${DCGM_PORT}" >/dev/null 2>&1 &
      PF_PID=$!
      metrics=""
      for _ in $(seq 1 15); do
        sleep 1
        if metrics="$(curl -sf "http://127.0.0.1:${local_port}/metrics" 2>/dev/null)"; then
          break
        fi
      done
      if [ -z "$metrics" ]; then
        fail "could not scrape http://${DCGM_SVC}.${DCGM_NS}:${DCGM_PORT}/metrics"
      elif printf '%s' "$metrics" | grep -q 'DCGM_FI_DEV_GPU_UTIL'; then
        pass "DCGM exporter serves DCGM_FI_DEV_GPU_UTIL"
        printf '%s' "$metrics" | grep 'DCGM_FI_DEV_GPU_UTIL' |
          sed -n '1,3p' | sed 's/^/      /'
      else
        fail "DCGM exporter responded but exposes no DCGM_FI_DEV_GPU_UTIL series"
      fi
      kill "$PF_PID" >/dev/null 2>&1 || true
      unset PF_PID
    fi
  else
    fail "service ${DCGM_SVC} not found in namespace ${DCGM_NS} (apply the baseline first)"
  fi
else
  skip "DCGM exporter scrape (no GPUs)"
fi

# ------------------------------------------------------------- 5. ingress
if kubectl get deployment ingress-nginx-controller -n "$INGRESS_NS" \
  >/dev/null 2>&1; then
  if kubectl wait --for=condition=ready pod -l "$INGRESS_SELECTOR" \
    -n "$INGRESS_NS" --timeout="${TIMEOUT}s" >/dev/null 2>&1; then
    pass "ingress-nginx controller pod is Ready"
  else
    fail "no Ready ingress-nginx controller pod in ${INGRESS_NS} after ${TIMEOUT}s"
    kubectl get pods -n "$INGRESS_NS" -l "$INGRESS_SELECTOR" 2>&1 |
      sed 's/^/      /' || true
  fi
else
  fail "deployment ingress-nginx-controller not found in ${INGRESS_NS} (apply the baseline first)"
fi

# ------------------------------------------------------------------ summary
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "smoke: ${FAILURES} check(s) failed, ${SKIPS} skipped" >&2
  exit 1
fi
echo "smoke: all executed checks passed, ${SKIPS} skipped"
