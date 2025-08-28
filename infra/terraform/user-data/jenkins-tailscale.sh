#!/bin/bash
set -euo pipefail

# Jenkins Server Initial Setup Script with Tailscale

# Variable configuration
HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"

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
    --secret-id "tailscale-jenkins-secret" \
    --query 'SecretString' \
    --output text | jq -r '.["tailscale-jenkins-key"]')

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


# Install Java 17 for Jenkins
echo "Installing Java 17..."
apt-get install -y openjdk-17-jdk

# Install Jenkins
echo "Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install -y jenkins

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Prepare Jenkins directories
mkdir -p /opt/jenkins
chown ubuntu:ubuntu /opt/jenkins


# Install Ansible (for Jenkins usage)
apt-get update
apt-get install -y python3-pip
pip3 install ansible ansible-vault

# Wait for Jenkins and get initial password
sleep 30
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Password file not found")

# Create status file
cat > /tmp/tailscale-jenkins-info.json << EOF
{
  "hostname": "$HOSTNAME",
  "tailscale_ip": "$TAILSCALE_IP",
  "jenkins_password": "$JENKINS_PASSWORD",
  "setup_completed": "$(date -Iseconds)"
}
EOF

# Completion marker
touch /var/lib/cloud/instance/boot-finished
echo "Jenkins server with Tailscale initialization completed at $(date)" > /var/log/init-complete.log
echo "Jenkins URL: http://$TAILSCALE_IP:8080"
echo "Initial admin password: $JENKINS_PASSWORD"