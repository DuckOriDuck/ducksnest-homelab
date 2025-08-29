#!/bin/bash
set -euo pipefail

# Kubernetes Control Plane EC2 with Tailscale

# vars
HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"
KUBERNETES_VERSION=v1.33
CRIO_VERSION=v1.33
OS_CODENAME="xUbuntu_24.04"

# system update
apt-get update
apt-get upgrade -y

# basic packages
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    tree \
    jq \
    vim \
    ufw

# Set hostname
hostnamectl set-hostname "$HOSTNAME"
if ! grep -q "$HOSTNAME" /etc/hosts; then
  echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
fi

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    AWS_CLI_ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
    AWS_CLI_ARCH="aarch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

curl "https://awscli.amazonaws.com/awscli-exe-linux-$AWS_CLI_ARCH.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Configure AWS CLI region
aws configure set region "$AWS_REGION"

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Get Tailscale auth key from AWS Secrets Manager and connect
echo "Retrieving Tailscale auth key from Secrets Manager..."
AUTH_KEY=$(aws secretsmanager get-secret-value \
    --secret-id "tailscale-cp-secret" \
    --query 'SecretString' \
    --output text | jq -r '.["tailscale-cp-key"]')

if [ -z "$AUTH_KEY" ] || [ "$AUTH_KEY" = "null" ]; then
    echo "ERROR: Failed to retrieve Tailscale auth key"
    exit 1
fi

# Connect to Tailscale
tailscale up \
    --authkey="$AUTH_KEY" \
    --hostname="$HOSTNAME" \
    --accept-routes \
    --accept-dns

# Wait for connection and get IP
sleep 10
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale connected with IP: $TAILSCALE_IP"


# Configure time synchronization
timedatectl set-timezone Asia/Seoul
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF


modprobe overlay
modprobe br_netfilter

# sysctl Variable setting
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install the dependencies for adding repositories
apt-get update
apt-get install -y software-properties-common curl

# add K8s repository
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O repository
curl -fsSL https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

# Install Kubernetes packages
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl start crio.service
sudo systemctl enable crio.service
sudo systemctl enable --now kubelet

# System optimization
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'fs.file-max=65536' >> /etc/sysctl.conf
sysctl -p


# Create status file
cat > /tmp/tailscale-cp-info.json << EOF
{
  "hostname": "$HOSTNAME",
  "tailscale_ip": "$TAILSCALE_IP",
  "kubernetes_version": "$KUBERNETES_VERSION",
  "setup_completed": "$(date -Iseconds)"
}
EOF

# Completion marker
touch /var/lib/cloud/instance/boot-finished
echo "Kubernetes Control Plane with Tailscale initialization completed at $(date)" > /var/log/init-complete.log
echo "Control Plane Tailscale IP: $TAILSCALE_IP"