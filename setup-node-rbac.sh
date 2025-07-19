#!/bin/bash

# Setup RBAC for external worker nodes
set -e

echo "=== Setting up RBAC for worker nodes ==="

# Check if kubectl is available
if [[ ! -f "bin/kubectl" ]]; then
    echo "Error: kubectl not found. Make sure you run this after setting up binaries."
    exit 1
fi

echo "Creating RBAC for node bootstrap..."

cat > node-bootstrap-rbac.yaml <<EOF
# Allow bootstrap tokens to create CSRs
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: create-csrs-for-bootstrapping
subjects:
- kind: Group
  name: system:bootstrappers:worker
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:node-bootstrapper
  apiGroup: rbac.authorization.k8s.io
---
# Auto-approve CSRs for the group
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: auto-approve-csrs-for-group
subjects:
- kind: Group
  name: system:bootstrappers:worker
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
  apiGroup: rbac.authorization.k8s.io
---
# Auto-approve renewal CSRs for nodes
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: auto-approve-renewals-for-nodes
subjects:
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
  apiGroup: rbac.authorization.k8s.io
---
# Auto-approve server certificate CSRs for nodes
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: auto-approve-csrs-for-group-server
subjects:
- kind: Group
  name: system:bootstrappers:worker
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeserver
  apiGroup: rbac.authorization.k8s.io
EOF

# Wait for API server to be ready
echo "Waiting for API server to be available..."
timeout=30
while ! bin/kubectl cluster-info &>/dev/null && [ $timeout -gt 0 ]; do
    echo "Waiting for API server... ($timeout seconds left)"
    sleep 2
    timeout=$((timeout-2))
done

if [ $timeout -le 0 ]; then
    echo "✗ API server not available after 30 seconds"
    exit 1
fi

# Apply RBAC
bin/kubectl apply -f node-bootstrap-rbac.yaml
echo "✓ RBAC rules for worker nodes created successfully"
