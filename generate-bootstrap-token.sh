#!/bin/bash

# Generate bootstrap token for external worker nodes
set -e

echo "=== Generating bootstrap token for worker nodes ==="

# Check if kubectl is available
if [[ ! -f "bin/kubectl" ]]; then
    echo "Error: kubectl not found. Make sure you run this after setting up binaries."
    exit 1
fi

# Generate a random token
TOKEN_ID=$(head -c 3 /dev/urandom | xxd -p)
TOKEN_SECRET=$(head -c 8 /dev/urandom | xxd -p)
TOKEN="${TOKEN_ID}.${TOKEN_SECRET}"

echo "Creating bootstrap token..."

# Create token secret
cat > bootstrap-token.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-${TOKEN_ID}
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  token-id: $(echo -n ${TOKEN_ID} | base64 -w 0)
  token-secret: $(echo -n ${TOKEN_SECRET} | base64 -w 0)
  usage-bootstrap-authentication: $(echo -n "true" | base64 -w 0)
  usage-bootstrap-signing: $(echo -n "true" | base64 -w 0)
  auth-extra-groups: $(echo -n "system:bootstrappers:worker" | base64 -w 0)
EOF

# Wait for API server to be ready
echo "Waiting for API server to be available..."
timeout=30
while ! bin/kubectl cluster-info &>/dev/null && [ $timeout -gt 0 ]; do
    echo "Waiting for API server... ($timeout seconds left)"
    sleep 2
    timeout=$((timeout-2))
done

if [ $timeout -le 0 ]; then
    echo "✗ API server not available after 30 seconds"
    exit 1
fi

# Apply the token
bin/kubectl apply -f bootstrap-token.yaml

echo "✓ Bootstrap token created: $TOKEN"
echo "Token saved to: bootstrap-token.txt"

# Save token to file for reference
echo "$TOKEN" > bootstrap-token.txt

echo ""
echo "🔑 Bootstrap token: $TOKEN"
echo "Save this token - you'll need it for worker node setup!"
