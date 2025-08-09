#!/usr/bin/env bash
set -euo pipefail

START=${KIND_NODEPORT_START:-30000}
END=${KIND_NODEPORT_END:-30062}

# Validate nodePort range
if (( START > END )); then
  echo "KIND_NODEPORT_START (${START}) must be less than or equal to KIND_NODEPORT_END (${END})" >&2
  exit 1
fi

MAX_RANGE=128
if (( END - START > MAX_RANGE )); then
  echo "Port range ${START}-${END} exceeds maximum size of ${MAX_RANGE}" >&2
  exit 1
fi

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

