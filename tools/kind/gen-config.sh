#!/usr/bin/env bash
set -euo pipefail

START=${KIND_NODEPORT_START:-30000}
END=${KIND_NODEPORT_END:-30062}

cat <<EOF
# KIND cluster with 1 control plane and 2 workers
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
EOF

for port in $(seq "$START" "$END"); do
cat <<EOF
      - containerPort: $port
        hostPort: $port
        protocol: TCP
EOF
done

cat <<EOF
  - role: worker
  - role: worker
EOF

