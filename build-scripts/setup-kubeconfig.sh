#!/bin/bash

# Setup kubeconfig for admin access
set -e

# Source environment variables
source helpers/.env

echo "=== Setting up kubeconfig ==="/bash

# Setup kubeconfig for cluster access
set -e

echo "=== Setting up kubeconfig ==="

export KUBECONFIG=admin.conf

# Configure cluster
echo "Configuring cluster connection..."
bin/kubectl config set-cluster k8soncleverlinux \
  --certificate-authority=certs/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:4040

# Configure credentials
echo "Configuring admin credentials..."
bin/kubectl config set-credentials admin \
  --embed-certs=true \
  --client-certificate=certs/admin.pem \
  --client-key=certs/admin-key.pem

# Configure context
echo "Setting up context..."
bin/kubectl config set-context admin \
  --cluster=k8soncleverlinux \
  --user=admin

bin/kubectl config use-context admin

# Copy to standard location
echo "Copying kubeconfig to ~/.kube/config..."
mkdir -p ~/.kube && cp admin.conf ~/.kube/config

echo "✓ Kubeconfig setup complete"
