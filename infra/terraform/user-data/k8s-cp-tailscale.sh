#!/bin/bash
set -euo pipefail

# NixOS Control Plane EC2 with Tailscale

# vars
HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"

# Setup temporary Nix shell with required tools
export PATH="/run/current-system/sw/bin:$PATH"

# Retrieve required secrets via a temporary nix-shell session, then continue in the base shell
echo "Retrieving agenix SSH private key from Secrets Manager..."
AGENIX_KEY=$(nix-shell -p awscli2 jq --run "aws secretsmanager get-secret-value \
    --secret-id ducksnest-cp-ssh-4-TSLcert-secret \
    --region $AWS_REGION \
    --query SecretString \
    --output text | jq -r '.ducksnest_cert_mng_key_ec2'")

if [ -z "$AGENIX_KEY" ] || [ "$AGENIX_KEY" = "null" ]; then
    echo "ERROR: Failed to retrieve agenix SSH private key"
    exit 1
fi

# Install agenix SSH private key for certificate decryption
echo "Installing agenix SSH private key..."
mkdir -p /root/.ssh
echo "$AGENIX_KEY" | base64 -d > /root/.ssh/ducksnest_cert_mng_key
chmod 600 /root/.ssh/ducksnest_cert_mng_key
chown root:root /root/.ssh/ducksnest_cert_mng_key
echo "Agenix SSH key installed successfully"


# Get Tailscale auth key from AWS Secrets Manager
echo "Retrieving Tailscale auth key from Secrets Manager..."
AUTH_KEY=$(aws secretsmanager get-secret-value \
    --secret-id tailscale-cp-secret \
    --region ap-northeast-2 \
    --query SecretString \
    --output text | jq -r '.["tailscale-cp-key"]')

if [ -z "$AUTH_KEY" ] || [ "$AUTH_KEY" = "null" ]; then
    echo "ERROR: Failed to retrieve Tailscale auth key"
    exit 1
fi

tailscale up --authkey="$AUTH_KEY" --accept-routes --accept-dns

# Wait for connection and get IP
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale connected with IP: $TAILSCALE_IP"

# Create status file
cat > /tmp/tailscale-cp-info.json << EOF
{
  "hostname": "$HOSTNAME",
  "tailscale_ip": "$TAILSCALE_IP",
  "setup_completed": "$(date -Iseconds)"
}
EOF

NIX_CONFIG=$'experimental-features = nix-command flakes
substituters = s3://ducksnest-nix-cache?region=ap-northeast-2
require-sigs = false
narinfo-cache-negative-ttl = 0' \
  sudo nixos-rebuild switch \
    --flake 'github:DuckOriDuck/ducksnest-homelab?dir=infra/nix#ec2-controlplane' \
    --option builders '' \
    --option fallback false \
    --refresh
