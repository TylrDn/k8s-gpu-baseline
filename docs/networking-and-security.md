# Networking and security posture

What this baseline actually enforces, what it deliberately does not, and what
you must add before your own workloads can talk to anything.

## 1. The NetworkPolicy pair

Two policies ship in `manifests/networkpolicies/`, and **both apply only to the
`default` namespace**.

### `default-deny-all.yaml`

```yaml
spec:
  podSelector: {}          # every pod in namespace default
  policyTypes:
    - Ingress
    - Egress
```

An empty `podSelector` selects every pod in the namespace, and declaring both
policy types with no `ingress:`/`egress:` rules means "no allowed traffic in
either direction". This is the standard deny-by-default idiom from the
[Kubernetes NetworkPolicy documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/).

### `allow-dns-egress.yaml`

```yaml
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Egress to CoreDNS on 53/UDP and 53/TCP, and nothing else. Note the structure:
`namespaceSelector` and `podSelector` are two keys of a **single** `to` element,
so they are ANDed — kube-dns pods *in* `kube-system`, not "anything in
kube-system OR any kube-dns pod anywhere". The `kubernetes.io/metadata.name`
label is set automatically by the API server on every namespace since
Kubernetes 1.21
([NamespaceDefaultLabelName](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)).

NetworkPolicies are additive: pods in `default` end up with "deny everything
except DNS", because the union of both policies is what is permitted.

Without the DNS allowance, `default-deny-all` alone would break name resolution
for every pod in the namespace — the single most common way a first
deny-by-default rollout goes wrong.

### Requirements and limits

- **A CNI that enforces NetworkPolicy is required.** Calico, Cilium, Antrea,
  Weave and others do; the KIND default (kindnet) and plain flannel do **not**.
  On a cluster without enforcement these objects are accepted by the API server
  and silently do nothing, which is worse than not having them, because it looks
  secure. Verify with a real connectivity test, not by reading `kubectl get
  netpol`.
- **Only the `default` namespace is covered.** `kube-system`,
  `node-feature-discovery`, `gpu-telemetry`, `metrics-server` and
  `ingress-nginx` are unrestricted. That is deliberate: locking down the
  telemetry and ingress namespaces without knowing your CNI, DNS layout and
  scrape topology would break them. Copy the pair into your own namespaces when
  you are ready:

  ```bash
  for ns in team-a team-b; do
    kubectl -n "$ns" apply -f manifests/networkpolicies/
  done
  ```

  (The policy manifests hardcode `namespace: default`; use `kubectl -n <ns>
  create -f` on edited copies, or a Kustomize overlay that sets `namespace:`,
  rather than assuming `-n` overrides the embedded value.)
- NetworkPolicy is pod-level and does not apply to hostNetwork pods or to
  traffic from the node itself.

## 2. What you must add for your own workloads

Anything you deploy into `default` will be able to resolve DNS and nothing else.
Add narrowly scoped allow rules next to your workload. Three common ones:

**Allow a frontend to reach a backend inside the namespace:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

Plus the matching egress on the frontend, since egress is denied too:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
```

**Allow ingress-nginx to reach your service:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
          podSelector:
            matchLabels:
              app: ingress-nginx
```

The `app: ingress-nginx` label is the one set by
`manifests/ingress-nginx.yaml`; upstream ingress-nginx uses
`app.kubernetes.io/name: ingress-nginx` instead, so check which controller you
actually installed.

**Allow Prometheus to scrape the DCGM exporter.** The exporter lives in
`gpu-telemetry`, which has no policies today. The moment you add a deny-all
there, Prometheus needs an explicit ingress allowance on port 9400 from its own
namespace.

Egress to the public internet (image pulls happen on the node, but API calls
from pods do not) needs its own rule; keep it to specific CIDRs and ports rather
than `to: [{}]`.

## 3. metrics-server hardening

`manifests/metrics-server.yaml` runs metrics-server with an **empty argument
list**:

```yaml
containers:
  - name: metrics-server
    image: registry.k8s.io/metrics-server/metrics-server:v0.6.4
    # No insecure flags by default; add --kubelet-insecure-tls only in
    # dev overlays (see kustomize/overlays/dev/metrics-server-patch.yaml)
    args: []
```

That is the security-relevant decision in this repository: kubelet certificate
verification stays **on** in the base and in the `prod` overlay. Many quickstart
manifests ship `--kubelet-insecure-tls` unconditionally, which disables
verification of the kubelet's serving certificate and exposes the metrics path
to a man-in-the-middle inside the cluster network.

The relaxation is confined to the dev overlay
(`kustomize/overlays/dev/metrics-server-patch.yaml`):

```yaml
spec:
  template:
    spec:
      containers:
        - name: metrics-server
          args:
            - --kubelet-insecure-tls
```

Confirm which one you are about to apply:

```bash
diff <(kubectl kustomize kustomize/overlays/prod) \
     <(kubectl kustomize kustomize/overlays/dev)
```

The only difference between the two overlays is those two lines.

For real clusters the correct fix is not the flag but a kubelet serving
certificate signed by the cluster CA — see
[metrics-server's requirements](https://github.com/kubernetes-sigs/metrics-server)
and
[kubelet TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/).

## 4. Other security-relevant facts, stated plainly

| Fact | Where | Why it matters |
|------|-------|----------------|
| The NVIDIA device plugin container runs with `securityContext.privileged: true` | `manifests/nvidia-device-plugin.yaml` | Required for device access, but it is a privileged workload in `kube-system`. Upstream's alternative is finer-grained capabilities plus device mounts. |
| The device plugin uses `--fail-on-init-error=false` | same file | Fails open: the pod stays Running when initialisation fails, so absence of GPUs is silent. Verify with allocatable resources, not pod status. |
| No PodSecurity admission labels are set on any namespace | all namespace objects | Add `pod-security.kubernetes.io/enforce` labels per [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) to suit your cluster. The privileged device plugin needs the `privileged` level. |
| No `resources.requests`/`limits` on any container | all workloads | Add them before running this next to production workloads. |
| No ServiceAccount or RBAC for the device plugin, metrics-server or ingress-nginx | respective manifests | Each falls back to the namespace `default` ServiceAccount. metrics-server and ingress-nginx genuinely need RBAC upstream provides; see [Known gaps](../README.md#known-gaps). |
| `dcgm-exporter` and `nfd-worker` do have their own ServiceAccounts | their manifests | But no Role/RoleBinding is created for them here. |
| The ingress Service is `type: LoadBalancer` on port 80 with no TLS | `manifests/ingress-nginx.yaml` | On a cloud provider this provisions a public load balancer. Terminate TLS and restrict source ranges before exposing anything real. |
| Images are pinned to explicit tags, not `latest`, but not to digests | all manifests | Tags are mutable. Pin by `@sha256:...` if you need reproducibility. |

## Further reading

- [Kubernetes NetworkPolicy concepts](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Kubernetes security best practices for cluster hardening](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server)
