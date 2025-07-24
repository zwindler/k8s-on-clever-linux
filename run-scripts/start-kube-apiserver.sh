#!/bin/bash

# Start kube-apiserver
set -e

sleep 5  # Ensure etcd is ready before starting API server

echo "=== Starting kube-apiserver ==="

# Create logs directory if it doesn't exist
mkdir -p logs

# Certificate options for API server
API_CERTS_OPTS="--client-ca-file=certs/ca.pem \
            --tls-cert-file=certs/admin.pem \
            --tls-private-key-file=certs/admin-key.pem \
            --service-account-key-file=certs/admin.pem \
            --service-account-signing-key-file=certs/admin-key.pem \
            --service-account-issuer=https://kubernetes.default.svc.cluster.local"

# etcd connection options
ETCD_OPTS="--etcd-cafile=certs/ca.pem \
           --etcd-certfile=certs/admin.pem \
           --etcd-keyfile=certs/admin-key.pem \
           --etcd-servers=https://127.0.0.1:2379"

# Start kube-apiserver
echo "Starting kube-apiserver..."
echo "Logs: logs/kube-apiserver.log"
exec bin/kube-apiserver ${API_CERTS_OPTS} ${ETCD_OPTS} \
            --allow-privileged \
            --authorization-mode=Node,RBAC \
            --enable-bootstrap-token-auth \
            --secure-port 4040 \
            >> logs/kube-apiserver.log 2>&1
