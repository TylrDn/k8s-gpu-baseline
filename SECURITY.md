# Security Policy

## Supported versions

This repository publishes Kubernetes manifests rather than a compiled artifact.
Only the tip of `main` is maintained.

| Version | Supported |
|---------|-----------|
| `main`  | yes |
| older commits / tags | no |

## Reporting a vulnerability

Report privately through GitHub: **Security → Advisories → Report a
vulnerability** at
<https://github.com/TylrDn/k8s-gpu-baseline/security/advisories>, which follows
[GitHub's coordinated disclosure process](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).
Please do not open a public issue first.

Include the affected file and commit sha, the cluster context needed to
reproduce, and the impact you expect. Expect an acknowledgement within 7 days.

For vulnerabilities in the upstream components these manifests deploy — the
NVIDIA device plugin, DCGM exporter, Node Feature Discovery, metrics-server or
ingress-nginx — report to those projects; we will bump the pinned tags here once
a fixed release exists.

## Known security-relevant defaults

Documented rather than hidden. Full detail in
[docs/networking-and-security.md](docs/networking-and-security.md).

- The NVIDIA device plugin container runs with `securityContext.privileged:
  true` in `kube-system` (`manifests/nvidia-device-plugin.yaml`).
- The device plugin runs with `--fail-on-init-error=false`, so an initialisation
  failure is silent. Verify GPUs via `status.allocatable`, not pod status.
- metrics-server runs with `args: []` in the base and prod overlay, keeping
  kubelet certificate verification enabled. `--kubelet-insecure-tls` is added
  **only** by `kustomize/overlays/dev`. Do not apply the dev overlay to a real
  cluster.
- The NetworkPolicies cover the `default` namespace only, and require a CNI that
  enforces NetworkPolicy (Calico, Cilium, Antrea, ...). On kindnet or plain
  flannel they are accepted by the API server and silently do nothing.
- The ingress Service is `type: LoadBalancer` on port 80 with no TLS
  termination. On a cloud provider this provisions a public load balancer.
- No namespace sets `pod-security.kubernetes.io/*` admission labels, and no
  container sets resource requests or limits.
- Images are pinned to explicit tags but not to digests; tags are mutable.

## Scope

In scope: the manifests, Kustomize overlays, `scripts/smoke.sh`, the Makefile
and the CI workflow in this repository. Out of scope: vulnerabilities in the
upstream container images themselves, and misconfiguration of a cluster where
this baseline was adapted.
