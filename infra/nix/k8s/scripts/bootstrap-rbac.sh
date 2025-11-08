#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Kubernetes RBAC rules
#
# Usage: bootstrap-rbac.sh <kubectl_path> <ca_cert> <server_address> <rbac_manifests_dir> [max_retries] [retry_interval]
#
# Arguments:
#   kubectl_path         - Path to kubectl binary
#   ca_cert              - Path to CA certificate
#   server_address       - Kubernetes API server address (e.g., https://hostname:6443)
#   rbac_manifests_dir   - Directory containing RBAC manifests
#   max_retries          - (optional) Maximum number of API server health check retries (default: 30)
#   retry_interval       - (optional) Seconds to wait between retries (default: 2)

KUBECTL="${1:?Missing kubectl_path}"
CA_CERT="${2:?Missing ca_cert}"
SERVER_ADDRESS="${3:?Missing server_address}"
RBAC_MANIFESTS_DIR="${4:?Missing rbac_manifests_dir}"
MAX_RETRIES="${5:-30}"
RETRY_INTERVAL="${6:-2}"

# Wait for API server to be ready
echo "Waiting for API server to be ready..."
for i in $(seq 1 "$MAX_RETRIES"); do
  if curl -s --cacert "$CA_CERT" "${SERVER_ADDRESS}/healthz" > /dev/null 2>&1; then
    echo "API server is ready"
    break
  fi
  echo "Attempt $i/$MAX_RETRIES: API server not ready yet, waiting..."
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "Error: API server did not become ready after $MAX_RETRIES attempts"
    exit 1
  fi
  sleep "$RETRY_INTERVAL"
done

# Create RBAC directory if it doesn't exist
mkdir -p "$RBAC_MANIFESTS_DIR"

# Apply RBAC manifests
if [ -d "$RBAC_MANIFESTS_DIR" ] && [ -n "$(ls -A "$RBAC_MANIFESTS_DIR"/*.yaml 2>/dev/null || true)" ]; then
  echo "Applying RBAC manifests from $RBAC_MANIFESTS_DIR"
  for manifest in "$RBAC_MANIFESTS_DIR"/*.yaml; do
    if [ -f "$manifest" ]; then
      echo "Applying $manifest"
      if ! "$KUBECTL" apply -f "$manifest"; then
        echo "Warning: Failed to apply $manifest"
      fi
    fi
  done
  echo "Bootstrap RBAC rules applied"
else
  echo "Warning: No RBAC manifests found in $RBAC_MANIFESTS_DIR"
fi
