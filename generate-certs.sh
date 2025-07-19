#!/bin/bash

# Generate certificates for the Kubernetes cluster
set -e

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
    "k8soncleverlinux.zwindler.fr"
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
    "k8soncleverlinux.zwindler.fr"
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

cd ..

echo "✓ Certificates generated successfully"
ls -la certs/
