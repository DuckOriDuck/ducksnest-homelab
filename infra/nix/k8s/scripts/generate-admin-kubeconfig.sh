#!/usr/bin/env bash
set -euo pipefail

# Generate Kubernetes admin kubeconfig file
#
# Usage: generate-admin-kubeconfig.sh <output_path> <ca_cert> <admin_cert> <admin_key> <server_address> [cluster_name] [user_name]
#
# Arguments:
#   output_path     - Path where kubeconfig will be written
#   ca_cert         - Path to CA certificate
#   admin_cert      - Path to admin client certificate
#   admin_key       - Path to admin client key
#   server_address  - Kubernetes API server address (e.g., https://hostname:6443)
#   cluster_name    - (optional) Cluster name (default: ducksnest-k8s)
#   user_name       - (optional) User name (default: kubernetes-admin)

KUBECONFIG_PATH="${1:?Missing output_path}"
CA_CERT="${2:?Missing ca_cert}"
ADMIN_CERT="${3:?Missing admin_cert}"
ADMIN_KEY="${4:?Missing admin_key}"
SERVER_ADDRESS="${5:?Missing server_address}"
CLUSTER_NAME="${6:-ducksnest-k8s}"
USER_NAME="${7:-kubernetes-admin}"

# Create directory if it doesn't exist
mkdir -p "$(dirname "$KUBECONFIG_PATH")"

# Generate kubeconfig
cat > "$KUBECONFIG_PATH" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${CA_CERT}
    server: ${SERVER_ADDRESS}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USER_NAME}
  name: default
current-context: default
users:
- name: ${USER_NAME}
  user:
    client-certificate: ${ADMIN_CERT}
    client-key: ${ADMIN_KEY}
EOF

# Set secure permissions
chmod 600 "$KUBECONFIG_PATH"

echo "Admin kubeconfig generated at $KUBECONFIG_PATH"
