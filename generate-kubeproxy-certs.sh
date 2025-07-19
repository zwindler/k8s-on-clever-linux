#!/bin/bash

# Generate kube-proxy certificate and kubeconfig
set -e

# Source environment variables
source .env

echo "=== Generating kube-proxy certificates and kubeconfig ==="

# Check if we're in the right directory
if [[ ! -f "bin/kubectl" ]] || [[ ! -d "certs" ]]; then
    echo "Error: Run this from the kubernetes directory with certs/ and bin/ folders"
    exit 1
fi

cd certs

echo "Creating kube-proxy certificate..."

# Create kube-proxy certificate signing request
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Pessac",
      "O": "system:node-proxier",
      "OU": "dumber k8s",
      "ST": "Nouvelle Aquitaine"
    }
  ]
}
EOF

# Generate kube-proxy certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | ../bin/cfssljson -bare kube-proxy

cd ..

echo "Creating kube-proxy kubeconfig..."

# Create kube-proxy kubeconfig with certificates
export KUBECONFIG=kube-proxy.conf

bin/kubectl config set-cluster k8soncleverlinux \
  --certificate-authority=certs/ca.pem \
  --embed-certs=true \
  --server=${API_SERVER_ENDPOINT}

bin/kubectl config set-credentials system:kube-proxy \
  --embed-certs=true \
  --client-certificate=certs/kube-proxy.pem \
  --client-key=certs/kube-proxy-key.pem

bin/kubectl config set-context default \
  --cluster=k8soncleverlinux \
  --user=system:kube-proxy

bin/kubectl config use-context default

echo "✓ kube-proxy certificate and kubeconfig created"
echo "Files created:"
echo "  - certs/kube-proxy.pem"
echo "  - certs/kube-proxy-key.pem" 
echo "  - kube-proxy.conf"

echo ""
echo "Copy kube-proxy.conf to your worker node at /etc/kubernetes/kube-proxy.conf"
