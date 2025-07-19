#!/bin/bash

# Generate setup script for external worker nodes
set -e

# Source environment variables
source .env

echo "=== Generating worker node setup script ==="
echo "Versions:"
echo "  Kubernetes: ${K8S_VERSION}"
echo "  Containerd: ${CONTAINERD_VERSION}"
echo "  Runc: ${RUNC_VERSION}"
echo "  CNI: ${CNI_VERSION}"
echo ""

# Configuration
BOOTSTRAP_TOKEN=$(cat bootstrap-token.txt 2>/dev/null || echo "REPLACE_WITH_BOOTSTRAP_TOKEN")

# Check if CA certificate exists
if [[ ! -f "certs/ca.pem" ]]; then
    echo "Error: CA certificate not found. Make sure certificates are generated first."
    exit 1
fi

# Check if kube-proxy kubeconfig exists
if [[ ! -f "kube-proxy.conf" ]]; then
    echo "Error: kube-proxy.conf not found. Make sure kube-proxy certificates are generated first."
    echo "Run: ./generate-kubeproxy-certs.sh"
    exit 1
fi

echo "Creating worker node setup script..."

cat > setup-worker-node.sh <<EOF
#!/bin/bash

# External Worker Node Setup Script for Kubernetes
# Run this script on your external worker node

set -e

# Configuration - Auto-detected with override options
# Override these variables before running if the auto-detection is incorrect
NODE_NAME_OVERRIDE=""  # Leave empty to use hostname, or set to override
NODE_IP_OVERRIDE=""    # Leave empty to auto-detect, or set to override (e.g., "192.168.1.100")
API_SERVER_ENDPOINT="${API_SERVER_ENDPOINT}"
BOOTSTRAP_TOKEN="REPLACE_WITH_BOOTSTRAP_TOKEN"  # Replace with actual token

# Auto-detect node name and IP
if [[ -n "\$NODE_NAME_OVERRIDE" ]]; then
    NODE_NAME="\$NODE_NAME_OVERRIDE"
    echo "Using override NODE_NAME: \$NODE_NAME"
else
    NODE_NAME="\$(hostname)"
    echo "Auto-detected NODE_NAME: \$NODE_NAME"
fi

if [[ -n "\$NODE_IP_OVERRIDE" ]]; then
    NODE_IP="\$NODE_IP_OVERRIDE"
    echo "Using override NODE_IP: \$NODE_IP"
else
    # Try to detect the main IP address (excluding loopback and docker interfaces)
    NODE_IP=\$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if(\$i=="src") print \$(i+1); exit}')
    
    # Fallback to first non-loopback IP if route detection fails
    if [[ -z "\$NODE_IP" ]]; then
        NODE_IP=\$(ip addr show | grep -E 'inet [0-9]+\.' | grep -v '127.0.0.1' | grep -v 'docker' | head -1 | awk '{print \$2}' | cut -d/ -f1)
    fi
    
    if [[ -n "\$NODE_IP" ]]; then
        echo "Auto-detected NODE_IP: \$NODE_IP"
    else
        echo "ERROR: Could not auto-detect NODE_IP. Please set NODE_IP_OVERRIDE at the top of this script."
        echo "Example: NODE_IP_OVERRIDE=\"192.168.1.100\""
        exit 1
    fi
fi

# Version configuration
K8S_VERSION="${K8S_VERSION}"
CONTAINERD_VERSION="${CONTAINERD_VERSION}"
RUNC_VERSION="${RUNC_VERSION}"
CNI_VERSION="${CNI_VERSION}"

echo "=== Setting up Kubernetes worker node: \$NODE_NAME ==="

echo "Node configuration:"
echo "  NODE_NAME: \$NODE_NAME"
echo "  NODE_IP: \$NODE_IP"
echo "  API_SERVER_ENDPOINT: \$API_SERVER_ENDPOINT"
echo ""

# System prerequisites
echo "Setting up system prerequisites..."

# Install required packages
echo "Installing required packages..."
if command -v apt-get >/dev/null 2>&1; then
    # Ubuntu/Debian
    sudo apt-get update
    sudo apt-get install -y curl wget socat conntrack ipset
elif command -v yum >/dev/null 2>&1; then
    # RHEL/CentOS
    sudo yum install -y curl wget socat conntrack-tools ipset
elif command -v dnf >/dev/null 2>&1; then
    # Fedora
    sudo dnf install -y curl wget socat conntrack-tools ipset
else
    echo "Warning: Unknown package manager. Please ensure curl, wget, socat, conntrack, and ipset are installed."
fi

# Load required kernel modules
echo "Loading required kernel modules..."
sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe nf_conntrack

# Make kernel modules persistent
echo "Making kernel modules persistent..."
sudo tee /etc/modules-load.d/k8s.conf <<MODULES_EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
MODULES_EOF

# Set sysctl parameters
echo "Configuring sysctl parameters..."
sudo tee /etc/sysctl.d/k8s.conf <<SYSCTL_EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.netfilter.nf_conntrack_max = 131072
SYSCTL_EOF

# Apply sysctl parameters
sudo sysctl --system

# Create directories
echo "Creating directories..."
sudo mkdir -p /etc/kubernetes/{manifests,pki}
sudo mkdir -p /var/lib/{kubelet,kube-proxy}
sudo mkdir -p /var/lib/kubelet/pki
sudo mkdir -p /opt/cni/bin
sudo mkdir -p /etc/cni/net.d

# Set proper permissions for kubelet directories
sudo chown -R root:root /var/lib/kubelet
sudo chmod 755 /var/lib/kubelet
sudo chmod 700 /var/lib/kubelet/pki

# Install container runtime (containerd)
echo "Installing containerd..."
curl -L https://github.com/containerd/containerd/releases/download/v\${CONTAINERD_VERSION}/containerd-\${CONTAINERD_VERSION}-linux-amd64.tar.gz -o containerd.tar.gz
sudo tar -C /usr/local -xzf containerd.tar.gz
sudo mkdir -p /usr/local/lib/systemd/system
curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o containerd.service
sudo mv containerd.service /usr/local/lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Configure containerd
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Install runc
echo "Installing runc..."
curl -L https://github.com/opencontainers/runc/releases/download/v\${RUNC_VERSION}/runc.amd64 -o runc
sudo install -m 755 runc /usr/local/sbin/runc

# Install CNI plugins
echo "Installing CNI plugins..."
curl -L https://github.com/containernetworking/plugins/releases/download/v\${CNI_VERSION}/cni-plugins-linux-amd64-v\${CNI_VERSION}.tgz -o cni-plugins.tgz
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

# Download Kubernetes binaries
echo "Downloading Kubernetes binaries..."
curl -L https://dl.k8s.io/v\${K8S_VERSION}/kubernetes-node-linux-amd64.tar.gz -o kubernetes-node.tar.gz
tar -xzf kubernetes-node.tar.gz
sudo cp kubernetes/node/bin/{kubelet,kube-proxy} /usr/local/bin/
sudo chmod +x /usr/local/bin/{kubelet,kube-proxy}

# Create CA certificate (replace with actual content)
echo "Creating CA certificate..."
sudo tee /etc/kubernetes/pki/ca.crt <<'CA_CERT_EOF'
REPLACE_WITH_CA_CERTIFICATE
CA_CERT_EOF

# Create kubelet bootstrap kubeconfig
echo "Creating kubelet bootstrap configuration..."
sudo tee /etc/kubernetes/bootstrap-kubelet.conf <<BOOTSTRAP_EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: \${API_SERVER_ENDPOINT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet-bootstrap
  name: default
current-context: default
users:
- name: kubelet-bootstrap
  user:
    token: \${BOOTSTRAP_TOKEN}
BOOTSTRAP_EOF

# Create kubelet configuration
echo "Creating kubelet configuration..."
sudo tee /var/lib/kubelet/config.yaml <<KUBELET_CONFIG_EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/pki/ca.crt"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
runtimeRequestTimeout: "15m"
# Don't specify TLS cert files - let kubelet create them during bootstrap
# tlsCertFile: "/var/lib/kubelet/pki/kubelet.crt"
# tlsPrivateKeyFile: "/var/lib/kubelet/pki/kubelet.key"
containerRuntimeEndpoint: "unix:///var/run/containerd/containerd.sock"
serverTLSBootstrap: true
rotateCertificates: true
KUBELET_CONFIG_EOF

# Create kubelet systemd service
echo "Creating kubelet service..."
sudo tee /etc/systemd/system/kubelet.service <<KUBELET_SERVICE_EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \\
  --kubeconfig=/etc/kubernetes/kubelet.conf \\
  --config=/var/lib/kubelet/config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --node-ip=\${NODE_IP} \\
  --hostname-override=\${NODE_NAME} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
KUBELET_SERVICE_EOF

# Create kube-proxy kubeconfig
echo "Creating kube-proxy configuration..."
sudo tee /etc/kubernetes/kube-proxy.conf <<'PROXY_CONFIG_EOF'
KUBE_PROXY_KUBECONFIG_PLACEHOLDER
PROXY_CONFIG_EOF

# Create kube-proxy configuration
echo "Creating kube-proxy configuration..."
sudo tee /var/lib/kube-proxy/config.conf <<PROXY_YAML_EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/etc/kubernetes/kube-proxy.conf"
mode: "iptables"
clusterCIDR: "10.0.0.0/16"
bindAddress: "\${NODE_IP}"
healthzBindAddress: "\${NODE_IP}:10256"
metricsBindAddress: "\${NODE_IP}:10249"
PROXY_YAML_EOF

# Create kube-proxy systemd service
echo "Creating kube-proxy service..."
sudo tee /etc/systemd/system/kube-proxy.service <<PROXY_SERVICE_EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/config.conf \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
PROXY_SERVICE_EOF

# Enable and start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy

echo ""
echo "✓ Worker node setup completed!"
echo ""
echo "Check status with:"
echo "  sudo systemctl status kubelet"
echo "  sudo systemctl status kube-proxy"
echo ""
echo "Check logs with:"
echo "  sudo journalctl -u kubelet -f"
echo "  sudo journalctl -u kube-proxy -f"
EOF

chmod +x setup-worker-node.sh

# Replace the bootstrap token in the script
if [[ "$BOOTSTRAP_TOKEN" != "REPLACE_WITH_BOOTSTRAP_TOKEN" ]]; then
    sed -i "s/REPLACE_WITH_BOOTSTRAP_TOKEN/${BOOTSTRAP_TOKEN}/" setup-worker-node.sh
fi

# Replace CA certificate in the script
if [[ -f "certs/ca.pem" ]]; then
    echo "Embedding CA certificate in worker script..."
    # Use a temporary file to handle multiline replacement safely
    temp_script=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" == "REPLACE_WITH_CA_CERTIFICATE" ]]; then
            cat certs/ca.pem
        else
            echo "$line"
        fi
    done < setup-worker-node.sh > "$temp_script"
    mv "$temp_script" setup-worker-node.sh
fi

# Replace kube-proxy kubeconfig placeholder
if [[ -f "kube-proxy.conf" ]]; then
    echo "Embedding kube-proxy kubeconfig in worker script..."
    # Use a temporary file to handle multiline replacement safely
    temp_script=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" == "KUBE_PROXY_KUBECONFIG_PLACEHOLDER" ]]; then
            cat kube-proxy.conf
        else
            echo "$line"
        fi
    done < setup-worker-node.sh > "$temp_script"
    mv "$temp_script" setup-worker-node.sh
else
    echo "Warning: kube-proxy.conf not found. Worker script will need manual kube-proxy configuration."
fi

echo "✓ Worker setup script generated: setup-worker-node.sh"
echo ""
echo "📋 Next steps:"
echo "1. Copy setup-worker-node.sh to your external worker node"
echo "2. (Optional) Edit NODE_NAME_OVERRIDE and NODE_IP_OVERRIDE if auto-detection is incorrect"
echo "3. Ensure your worker node has sudo privileges and internet access"
echo "4. Run the script on your worker node: sudo ./setup-worker-node.sh"
echo "5. Check the node joined with: kubectl get nodes"
echo ""
echo "ℹ️  The script will automatically:"
echo "   - Auto-detect hostname and IP address (with override options)"
echo "   - Install required packages (curl, wget, socat, conntrack, ipset)"
echo "   - Load necessary kernel modules"
echo "   - Configure sysctl parameters"
echo "   - Install container runtime (containerd)"
echo "   - Set up kubelet and kube-proxy with proper certificates"
