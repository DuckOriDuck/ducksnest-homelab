#!/usr/bin/env bash
set -euo pipefail

# Generate Calico CNI kubeconfig file
#
# Usage: generate-cni-kubeconfig.sh <output_path> <ca_cert> <cni_cert> <cni_key> <server_address> [cluster_name] [user_name]
#
# Arguments:
#   output_path     - Path where CNI kubeconfig will be written
#   ca_cert         - Path to CA certificate
#   cni_cert        - Path to CNI client certificate
#   cni_key         - Path to CNI client key
#   server_address  - Kubernetes API server address (e.g., https://hostname:6443)
#   cluster_name    - (optional) Cluster name (default: ducksnest-k8s)
#   user_name       - (optional) User name (default: calico-cni)

KUBECONFIG_PATH="${1:?Missing output_path}"
CA_CERT="${2:?Missing ca_cert}"
CNI_CERT="${3:?Missing cni_cert}"
CNI_KEY="${4:?Missing cni_key}"
SERVER_ADDRESS="${5:?Missing server_address}"
CLUSTER_NAME="${6:-ducksnest-k8s}"
USER_NAME="${7:-calico-cni}"

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
    client-certificate: ${CNI_CERT}
    client-key: ${CNI_KEY}
EOF

# Set permissions (readable by root and kubernetes group)
chmod 644 "$KUBECONFIG_PATH"

echo "CNI kubeconfig generated at $KUBECONFIG_PATH"
