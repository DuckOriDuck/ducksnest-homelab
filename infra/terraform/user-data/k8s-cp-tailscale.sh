#!/bin/bash
set -euo pipefail

# NixOS Control Plane EC2 with Tailscale

# vars
HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"

# Configure AWS CLI region
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

NIX_CONFIG=$'experimental-features = nix-command flakes\nsubstituters = s3://another-nix-cache-test?region=ap-northeast-2\nrequire-sigs = false\nnarinfo-cache-negative-ttl = 0' \
sudo nixos-rebuild switch \
  --flake 'github:DuckOriDuck/ducksnest-homelab?dir=infra/nix#ec2-controlplane' \
  --option builders '' \
  --option fallback false \
  --refresh

# Connect to Tailscale
tailscale up \
    --authkey="$AUTH_KEY" \
    --accept-routes \
    --accept-dns

# Wait for connection and get IP
sleep 10
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale connected with IP: $TAILSCALE_IP"

# Wait for Kubernetes API server to be ready
echo "Waiting for Kubernetes API server to be ready..."
while ! kubectl get nodes >/dev/null 2>&1; do
    echo "API server not ready, waiting 10 seconds..."
    sleep 10
done

echo "Kubernetes API server is ready!"

# Install Calico CNI with MTU optimization for Tailscale
echo "Installing Calico CNI with Tailscale MTU configuration..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# Wait for initial Calico to be ready
echo "Waiting for Calico to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s

# Configure MTU for Tailscale compatibility
echo "Configuring Calico MTU for Tailscale..."
kubectl patch installation default --type merge -p '{"spec":{"calicoNetwork":{"mtu":1280}}}'

echo "Calico installation with Tailscale MTU optimization completed!"


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
