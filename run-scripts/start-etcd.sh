#!/bin/bash

# Start etcd server
set -e

echo "=== Starting etcd server ==="

# Create logs directory if it doesn't exist
mkdir -p logs

# Certificate options
CERTS_OPTS="--client-cert-auth \
           --cert-file=certs/admin.pem \
           --key-file=certs/admin-key.pem \
           --trusted-ca-file=certs/ca.pem"

# HTTPS options
FORCE_HTTPS_OPTS="--advertise-client-urls https://127.0.0.1:2379 \
                  --listen-client-urls https://127.0.0.1:2379"

echo "Starting etcd with TLS..."
echo "Logs: logs/etcd.log"
exec etcd --data-dir etcd-data $CERTS_OPTS $FORCE_HTTPS_OPTS \
    >> logs/etcd.log 2>&1
