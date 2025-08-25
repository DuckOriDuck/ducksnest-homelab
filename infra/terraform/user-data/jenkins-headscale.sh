#!/bin/bash
set -euo pipefail

# Jenkins/Headscale Server Initial Setup Script

# Variable configuration
HOSTNAME="${hostname}"

# System update
apt-get update
apt-get upgrade -y

# Install basic packages
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

# Install Docker (Auto-detect ARM64/AMD64)
DOCKER_ARCH=$(dpkg --print-architecture)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$DOCKER_ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker service
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Configure time synchronization
timedatectl set-timezone Asia/Seoul
systemctl enable --now systemd-timesyncd

# Configure log rotation
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF
systemctl restart docker


# Prepare Jenkins directories
mkdir -p /opt/jenkins
chown ubuntu:ubuntu /opt/jenkins

# Prepare Headscale directories
mkdir -p /etc/headscale
mkdir -p /var/lib/headscale
chown ubuntu:ubuntu /var/lib/headscale

# Install Ansible (for Jenkins usage)
apt-get update
apt-get install -y python3-pip
pip3 install ansible ansible-vault

# Completion marker
touch /var/lib/cloud/instance/boot-finished
echo "Jenkins/Headscale server initialization completed at $(date)" > /var/log/init-complete.log