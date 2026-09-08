# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- **Extracted the IBM i tooling into its own repository.** `src/ibmi_ops/**`,
  `java/**`, `tests/**`, `samples/**`, `pyproject.toml`, `uv.lock` and
  `.env.example` were never part of the GPU baseline; the root `pyproject.toml`
  was literally `name = "ibmi-ops-suite"`. They now live, with file history
  preserved via `git filter-repo`, in
  [TylrDn/ibmi-ops-suite](https://github.com/TylrDn/ibmi-ops-suite), extracted
  at commit `632d36a791632f1174fd0bc2a6a930c97f4ead5b`.
- `scripts/tools/bootstrap.sh` and `scripts/tools/bootstrap.ps1`, one-line stubs
  that printed "Bootstrap not implemented" and were referenced by nothing.

### Fixed

- **The Kustomize overlays could not be built at all.** `kustomize/base`
  referenced `manifests/networkpolicies` as a directory without a
  `kustomization.yaml`, and kustomize's load restrictor refuses individual files
  outside the kustomization root. `manifests/` and `manifests/networkpolicies/`
  now have their own `kustomization.yaml` and the base references the directory.
  `kubectl kustomize kustomize/overlays/prod` and `.../dev` both render (16
  objects).
- Kubernetes images now come from `registry.k8s.io` instead of the frozen
  `k8s.gcr.io` ([registry redirect announcement](https://kubernetes.io/blog/2023/03/10/image-registry-redirect/)):
  metrics-server v0.6.4, node-feature-discovery v0.14.0, ingress-nginx
  controller v1.9.4. Tags are unchanged. The two `nvcr.io` NVIDIA images are
  unaffected.
- `manifests/metrics-server.yaml` container list was indented 8 spaces instead
  of 6, which yamllint reported as an error.
- `pre-commit run --all-files` now passes. `check-yaml` gets
  `--allow-multiple-documents` for the multi-object manifests, and yamllint runs
  against an explicit `.yamllint.yaml`.

### Changed

- **`make smoke` is now a real test.** It previously ran an interactive
  `kubectl run` and then curled the hardcoded external URL
  `http://example.com/healthz`, which verified nothing about the cluster.
  `scripts/smoke.sh` checks cluster reachability, sums allocatable
  `nvidia.com/gpu` (skipping the GPU checks with an explicit message on
  CPU-only clusters such as KIND), runs and waits on an `nvidia-smi` Job,
  scrapes the DCGM exporter for `DCGM_FI_DEV_GPU_UTIL`, and waits for a Ready
  ingress-nginx controller pod. It exits non-zero on failure and cleans up
  after itself.
- `kustomize/overlays/dev` migrated from `patchesStrategicMerge`, deprecated
  since Kustomize v5, to `patches:`. Rendered output is byte-for-byte identical.
- Both overlays now carry `apiVersion`/`kind` and a comment explaining their
  purpose; `prod` is documented as an intentional pass-through of `base`.
- README rewritten: scope statement, mermaid architecture diagram, component
  table with pinned images and namespaces, layout rebuilt from `git ls-files`,
  overlay diff, a "Known gaps" table, and a documentation index.

### Added

- `docs/gpu-baseline.md` — GPU lifecycle walkthrough (NFD, device plugin,
  scheduling a GPU pod, DCGM metrics, `kubectl top`, smoke-test output and exit
  codes) with a troubleshooting table and upstream documentation links.
- `docs/networking-and-security.md` — the default-deny + allow-DNS posture, what
  to add for your own workloads, and the metrics-server TLS hardening.
- `scripts/smoke.sh`, plus `make help` (the new default goal) and the
  `deploy-dev`, `render` and `lint` targets.
- `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`.
- CI now renders and `kubeconform`-validates **both** overlays (previously only
  `prod`), runs `pre-commit` over all files, and shellchecks `scripts/smoke.sh`.
- `shellcheck` and `check-executables-have-shebangs` pre-commit hooks.

[Unreleased]: https://github.com/TylrDn/k8s-gpu-baseline/commits/main
