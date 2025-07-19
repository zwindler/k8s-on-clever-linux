#!/bin/bash

# Display current version configuration
set -e

# Source environment variables
source .env

echo "=== Current Version Configuration ==="
echo ""
echo "🚀 Kubernetes: ${K8S_VERSION}"
echo "📦 Container Runtime:"
echo "   • Containerd: ${CONTAINERD_VERSION}"
echo "   • Runc: ${RUNC_VERSION}"
echo "   • CNI: ${CNI_VERSION}"
echo "💾 etcd: ${ETCD_VERSION}"
echo "🏗️  Architecture: ${ARCH}"
echo "🌐 API Server: ${API_SERVER_ENDPOINT}"
echo ""
echo "📝 To update versions, edit .env file"
