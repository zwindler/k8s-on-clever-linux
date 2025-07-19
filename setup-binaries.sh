#!/bin/bash

# Setup Kubernetes binaries and tools
set -e

# Source environment variables
source .env

echo "=== Setting up Kubernetes binaries (v${K8S_VERSION}) ==="

# Create directories
mkdir -p bin/
mkdir -p etcd-data
chmod 700 etcd-data

# Download and extract Kubernetes binaries
echo "Downloading Kubernetes server binaries..."
curl -L https://dl.k8s.io/v$K8S_VERSION/kubernetes-server-linux-$ARCH.tar.gz -o kubernetes-server-linux-$ARCH.tar.gz
tar -zxf kubernetes-server-linux-${ARCH}.tar.gz

# Move binaries to bin/
for BINARY in kubectl kube-apiserver kube-scheduler kube-controller-manager kubelet kube-proxy; do
    mv kubernetes/server/bin/${BINARY} bin/
done

# Cleanup
rm kubernetes-server-linux-${ARCH}.tar.gz
rm -rf kubernetes

# Download cfssl tools
echo "Downloading cfssl tools..."
curl -L https://github.com/cloudflare/cfssl/releases/download/v1.6.5/cfssljson_1.6.5_linux_amd64 -o cfssljson_1.6.5_linux_amd64
mv cfssljson_1.6.5_linux_amd64 bin/cfssljson
chmod +x bin/cfssljson

# Add kubectl autocomplete
echo "Setting up kubectl autocompletion..."
echo 'source <(kubectl completion bash)' >>~/.bashrc

echo "✓ Binaries setup complete"
ls -la bin/
