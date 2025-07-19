#!/bin/bash

# Start etcd server
set -e

echo "=== Starting etcd server ==="

# Certificate options
CERTS_OPTS="--client-cert-auth \
           --cert-file=certs/admin.pem \
           --key-file=certs/admin-key.pem \
           --trusted-ca-file=certs/ca.pem"

# HTTPS options
FORCE_HTTPS_OPTS="--advertise-client-urls https://127.0.0.1:2379 \
                  --listen-client-urls https://127.0.0.1:2379"

# Create logs directory
mkdir -p logs

echo "Starting etcd with TLS..."
etcd --data-dir etcd-data $CERTS_OPTS $FORCE_HTTPS_OPTS \
  > logs/etcd.log 2>&1 &

ETCD_PID=$!
echo "etcd started with PID: $ETCD_PID"
echo "etcd logs: logs/etcd.log"

# Wait a moment for etcd to start
sleep 3

# Basic health check
if kill -0 $ETCD_PID 2>/dev/null; then
    echo "✓ etcd is running"
else
    echo "✗ etcd failed to start"
    exit 1
fi
