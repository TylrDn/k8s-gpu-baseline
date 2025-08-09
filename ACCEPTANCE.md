# Acceptance Checklist

1. `make kind-up && make deploy-baseline` finishes without error.
2. `kubectl get pods -A` shows Running pods for metrics-server, ingress-nginx controller, NFD; device-plugin may be Pending on CPU-only clusters.
3. `make deploy-netpol` applies NetworkPolicies successfully.
4. `make smoke` prints cluster info and either:
   - Runs a CUDA pod and prints `nvidia-smi` table (if GPU available), or
   - Prints a friendly message that no GPU nodes were found.
5. `make kustomize-dev` and `make kustomize-prod` render valid YAML.
6. `pre-commit run --all-files` passes locally.
7. CI workflow succeeds on push.
