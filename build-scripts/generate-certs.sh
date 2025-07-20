#!/bin/bash

# Generate certificates for the Kubernetes cluster
set -e

# Source environment variables
source helpers/.env

echo "=== Generating Kubernetes certificates ==="

# Create certs directory
mkdir -p certs && cd certs

# Create CA configuration
echo "Creating CA configuration..."
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

# Create CA certificate signing request
echo "Creating CA certificate..."
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Pessac",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Nouvelle Aquitaine"
    }
  ],
  "hosts": [
    "127.0.0.1",
    "localhost",
    "${K8S_DOMAIN}"
  ]
}
EOF

# Generate CA certificate
cfssl gencert -initca ca-csr.json | ../bin/cfssljson -bare ca

# Create admin certificate signing request
echo "Creating admin certificate..."
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Pessac",
      "O": "system:masters",
      "OU": "dumber k8s",
      "ST": "Nouvelle Aquitaine"
    }
  ],
  "hosts": [
    "127.0.0.1",
    "localhost",
    "${K8S_DOMAIN}"
  ]
}
EOF

# Generate admin certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | ../bin/cfssljson -bare admin

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

echo "✓ Certificates and kubeconfigs generated successfully"
echo "Files created:"
echo "  - certs/ca.pem, certs/ca-key.pem"
echo "  - certs/admin.pem, certs/admin-key.pem"
echo "  - certs/kube-proxy.pem, certs/kube-proxy-key.pem"
echo "  - admin.conf (admin kubeconfig)"
echo "  - kube-proxy.conf (kube-proxy kubeconfig)"
ls -la certs/
