#!/bin/bash

# Setup RBAC for external worker nodes
set -e

echo "=== Setting up RBAC for worker nodes ==="

# Check if kubectl is available
if [[ ! -f "bin/kubectl" ]]; then
    echo "Error: kubectl not found. Make sure you run this after setting up binaries."
    exit 1
fi

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

# Apply RBAC from static manifest
echo "Applying RBAC rules from node-bootstrap-rbac.yaml..."
bin/kubectl apply -f node-bootstrap-rbac.yaml
echo "✓ RBAC rules for worker nodes created successfully"
