#!/bin/bash
# Dynamic setup worker - runs after control plane is up
set -e

echo "🔄 Dynamic setup worker starting..."
echo "Waiting for API server to be ready..."

# Wait for API server to be accessible
for i in {1..60}; do
    if ./bin/kubectl cluster-info &>/dev/null; then
        echo "✅ API server is ready!"
        break
    fi
    echo "⏳ Waiting for API server... ($i/60)"
    sleep 5
done

if ! ./bin/kubectl cluster-info &>/dev/null; then
    echo "❌ API server not ready after 5 minutes"
    exit 1
fi

echo ""
echo "🔑 Generating bootstrap token..."
./run-scripts/generate-bootstrap-token.sh

echo ""
echo "🔒 Setting up RBAC for worker nodes..."
./run-scripts/setup-node-rbac.sh

echo ""
echo "📝 Generating worker setup script..."
./run-scripts/generate-worker-script.sh

echo ""
echo "✅ Dynamic setup complete!"

# Keep the worker alive by waiting
while true; do
    sleep 30
    # Check if we need to regenerate anything (optional)
    if ! ./bin/kubectl cluster-info &>/dev/null; then
        echo "⚠️ API server connection lost, will retry setup when it's back..."
        exit 1  # This will trigger a restart
    fi
done