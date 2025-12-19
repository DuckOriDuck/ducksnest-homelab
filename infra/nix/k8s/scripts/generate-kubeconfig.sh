#!/usr/bin/env bash
set -euo pipefail

# Generate Kubernetes kubeconfig file
#
# Usage: generate-kubeconfig.sh <output_path> <ca_cert> <client_cert> <client_key> <server_address> <cluster_name> <user_name>
#
# Arguments:
#   output_path     - Path where kubeconfig will be written
#   ca_cert         - Path to CA certificate
#   client_cert     - Path to client certificate
#   client_key      - Path to client key
#   server_address  - Kubernetes API server address (e.g., https://hostname:6443)
#   cluster_name    - Cluster name
#   user_name       - User name for the kubeconfig

KUBECONFIG_PATH="${1:?Missing output_path}"
CA_CERT="${2:?Missing ca_cert}"
CLIENT_CERT="${3:?Missing client_cert}"
CLIENT_KEY="${4:?Missing client_key}"
SERVER_ADDRESS="${5:?Missing server_address}"
CLUSTER_NAME="${6:?Missing cluster_name}"
USER_NAME="${7:?Missing user_name}"

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
    client-certificate: ${CLIENT_CERT}
    client-key: ${CLIENT_KEY}
EOF

# Set secure permissions
chmod 600 "$KUBECONFIG_PATH"

echo "Kubeconfig for ${USER_NAME} generated at $KUBECONFIG_PATH"