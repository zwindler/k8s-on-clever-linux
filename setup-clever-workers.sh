#!/bin/bash

# Setup Clever Cloud workers to use individual wrapper scripts
# 
# ⚠️  IMPORTANT: This script should be run LOCALLY on your computer
# It configures your Clever Cloud application to use simple wrapper scripts
# instead of complex command lines with arguments for CC_WORKER_COMMAND_x
#
set -e

echo "=== Setting up Clever Cloud workers for Kubernetes ==="
echo "⚠️  This script configures your Clever Cloud app - run it locally!"
echo "🔧 Using individual wrapper scripts instead of complex command lines"
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

# First, configure domain settings (user should modify these as needed)
echo ""
echo "📝 Configuring domain settings..."
echo "Setting default domain (change if needed):"
echo "  K8S_DOMAIN=k8soncleverlinux.zwindler.fr"
echo "  K8S_TCP_PORT=5131"
echo ""
echo "To use your own domain, run:"
echo "  clever env set K8S_DOMAIN your-domain.com"
echo "  clever env set K8S_TCP_PORT your-tcp-port"
echo ""

# Set default values that users can override
clever env set K8S_DOMAIN "k8soncleverlinux.zwindler.fr"
clever env set K8S_TCP_PORT "5131"

echo ""
echo "🔧 Setting up worker commands..."

# Worker 0: etcd
echo "Setting up etcd worker..."
clever env set CC_WORKER_COMMAND_0 "./run-scripts/start-etcd.sh"

# Worker 1: kube-apiserver
echo "Setting up kube-apiserver worker..."
clever env set CC_WORKER_COMMAND_1 "./run-scripts/start-kube-apiserver.sh"

# Worker 2: kube-controller-manager
echo "Setting up kube-controller-manager worker..."
clever env set CC_WORKER_COMMAND_2 "./run-scripts/start-kube-controller-manager.sh"

# Worker 3: kube-scheduler
echo "Setting up kube-scheduler worker..."
clever env set CC_WORKER_COMMAND_3 "./run-scripts/start-kube-scheduler.sh"

# Worker 4: post-boot setup (bootstrap token, RBAC, worker script generation)
# This worker handles the dynamic setup that needs the control plane to be running
chmod +x run-scripts/post-boot.sh
clever env set CC_WORKER_COMMAND_4 "run-scripts/post-boot.sh"

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
echo "  Worker 0: ./run-scripts/start-etcd.sh"
echo "  Worker 1: ./run-scripts/start-kube-apiserver.sh" 
echo "  Worker 2: ./run-scripts/start-kube-controller-manager.sh"
echo "  Worker 3: ./run-scripts/start-kube-scheduler.sh"
echo "  Worker 4: ./run-scripts/run-scripts/post-boot.sh (bootstrap tokens, RBAC, worker scripts)"
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
