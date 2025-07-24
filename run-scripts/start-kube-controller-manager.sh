#!/bin/bash

# Start kube-controller-manager
set -e

sleep 10  # Ensure API server is ready before starting controller manager

echo "=== Starting kube-controller-manager ==="

# Create logs directory if it doesn't exist
mkdir -p logs

# Certificate options for controller manager
CONTROLLER_CERTS_OPTS="--cluster-signing-cert-file=certs/ca.pem \
            --cluster-signing-key-file=certs/ca-key.pem \
            --service-account-private-key-file=certs/admin-key.pem \
            --root-ca-file=certs/ca.pem"

# Start kube-controller-manager
echo "Starting kube-controller-manager..."
echo "Logs: logs/kube-controller-manager.log"
exec bin/kube-controller-manager ${CONTROLLER_CERTS_OPTS} \
--kubeconfig admin.conf \
--use-service-account-credentials \
--cluster-cidr=10.0.0.0/16 \
--allocate-node-cidrs=true \
>> logs/kube-controller-manager.log 2>&1
