#!/bin/bash

# Setup Clever Cloud workers to replace start-etcd.sh and start-control-plane.sh
# 
# ⚠️  IMPORTANT: This script should be run LOCALLY on your computer
# It configures your Clever Cloud application to use workers instead of shell scripts.
#
set -e

echo "=== Setting up Clever Cloud workers for Kubernetes ==="
echo "⚠️  This script configures your Clever Cloud app - run it locally!"
echo ""

# Check if clever CLI is available
if ! command -v clever &> /dev/null; then
    echo "❌ Error: 'clever' CLI not found!"
    echo "Please install it first: https://www.clever-cloud.com/doc/clever-tools/getting_started/"
    exit 1
fi

# Check if we're linked to an app
if [ ! -f .clever.json ]; then
    echo "❌ Error: No .clever.json found!"
    echo "Please link to your Clever Cloud app first:"
    echo "  clever link <app_id>"
    exit 1
fi

echo "Setting up workers via clever CLI..."

# Worker 0: etcd
echo "Setting up etcd worker..."
clever env set CC_WORKER_COMMAND_0 "etcd --data-dir etcd-data --client-cert-auth --cert-file=certs/admin.pem --key-file=certs/admin-key.pem --trusted-ca-file=certs/ca.pem --advertise-client-urls https://127.0.0.1:2379 --listen-client-urls https://127.0.0.1:2379"

# Worker 1: kube-apiserver
echo "Setting up kube-apiserver worker..."
clever env set CC_WORKER_COMMAND_1 "bin/kube-apiserver --client-ca-file=certs/ca.pem --tls-cert-file=certs/admin.pem --tls-private-key-file=certs/admin-key.pem --enable-bootstrap-token-auth --service-account-key-file=certs/admin.pem --service-account-signing-key-file=certs/admin-key.pem --service-account-issuer=https://kubernetes.default.svc.cluster.local --etcd-cafile=certs/ca.pem --etcd-certfile=certs/admin.pem --etcd-keyfile=certs/admin-key.pem --etcd-servers=https://127.0.0.1:2379 --allow-privileged --authorization-mode=Node,RBAC --secure-port 4040"

# Worker 2: kube-controller-manager
echo "Setting up kube-controller-manager worker..."
clever env set CC_WORKER_COMMAND_2 "bin/kube-controller-manager --cluster-signing-cert-file=certs/ca.pem --cluster-signing-key-file=certs/ca-key.pem --service-account-private-key-file=certs/admin-key.pem --root-ca-file=certs/ca.pem --kubeconfig admin.conf --use-service-account-credentials --cluster-cidr=10.0.0.0/16 --allocate-node-cidrs=true"

# Worker 3: kube-scheduler
echo "Setting up kube-scheduler worker..."
clever env set CC_WORKER_COMMAND_3 "bin/kube-scheduler --kubeconfig admin.conf"

# Worker 4: HTTP server (from start-services.sh)
echo "Setting up HTTP server worker..."
clever env set CC_WORKER_COMMAND_4 "python3 -m http.server 8080 --bind 0.0.0.0"

# Set restart policy (optional, defaults to on-failure)
echo "Setting worker restart policy..."
clever env set CC_WORKER_RESTART "on-failure"

# Set restart delay (optional, defaults to 1 second)
echo "Setting worker restart delay..."
clever env set CC_WORKER_RESTART_DELAY "3"

echo ""
echo "✓ Clever Cloud workers configured!"
echo ""
echo "Workers that will be started by Clever Cloud:"
echo "  Worker 0: etcd database"
echo "  Worker 1: kube-apiserver" 
echo "  Worker 2: kube-controller-manager"
echo "  Worker 3: kube-scheduler"
echo "  Worker 4: HTTP server on port 8080"
echo ""
echo "All workers will:"
echo "  - Restart automatically on failure"
echo "  - Wait 3 seconds before restarting"
echo "  - Run in the application directory"
echo "  - Be managed by systemd"
echo ""
echo "To deploy and start the workers:"
echo "  clever deploy"
echo ""
echo "To check worker status:"
echo "  clever logs"
echo ""
echo "To remove a worker:"
echo "  clever env unset CC_WORKER_COMMAND_X"
