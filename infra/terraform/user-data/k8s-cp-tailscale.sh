#!/bin/bash
set -euo pipefail

# NixOS Control Plane EC2 with Tailscale

# vars
HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"

# Download and populate Nix cache from S3
echo "Downloading Nix cache from S3..."
nix copy --all --from s3://another-nix-cache-test?region=ap-northeast-2 --experimental-features 'nix-command flakes' --no-check-sigs

# NixOS rebuild with flake configuration
echo "Rebuilding NixOS with flake configuration..."
sudo nixos-rebuild switch --flake 'github:DuckOriDuck/ducksnest-homelab/infra/nix?dir=infra/nix#ec2-controlplane' 

# Configure AWS CLI region (AWS CLI should be available through NixOS configuration)
aws configure set region "$AWS_REGION"

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

# Connect to Tailscale (Tailscale should be available through NixOS configuration)
tailscale up \
    --authkey="$AUTH_KEY" \
    --accept-routes \
    --accept-dns

# Wait for connection and get IP
sleep 10
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

# Completion marker
touch /var/lib/cloud/instance/boot-finished
echo "NixOS Control Plane with Tailscale initialization completed at $(date)" > /var/log/init-complete.log
echo "Control Plane Tailscale IP: $TAILSCALE_IP"