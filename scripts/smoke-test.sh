#!/usr/bin/env bash
set -euo pipefail

kubectl cluster-info

echo "Checking for core pods..."
kubectl get pods -A | grep -E 'nvidia|nfd|dcgm|metrics|ingress' || true

echo "Detecting GPU nodes..."
if kubectl get nodes -o jsonpath='{.items[?(@.status.allocatable.nvidia\\.com/gpu)].metadata.name}' | grep -q .; then
  echo "GPU node found, running CUDA test pod"
  cat <<'POD' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cuda-smoke
  namespace: default
spec:
  restartPolicy: Never
  containers:
    - name: cuda
      image: nvidia/cuda:12.1.1-base-ubuntu22.04
      command: ["/bin/sh","-c","nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
POD
  kubectl wait --for=condition=Ready pod/cuda-smoke --timeout=120s
  kubectl logs cuda-smoke
  kubectl delete pod cuda-smoke
else
  echo "No GPU nodes detected; skipping CUDA test."
fi
