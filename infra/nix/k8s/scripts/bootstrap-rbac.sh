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

# Set KUBECONFIG if not already set
if [ -z "${KUBECONFIG:-}" ]; then
  # Default location for admin kubeconfig
  export KUBECONFIG="/etc/kubernetes/cluster-admin.kubeconfig"
  echo "KUBECONFIG not set, using default: $KUBECONFIG"
fi

# Verify kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
  echo "Error: KUBECONFIG file not found at: $KUBECONFIG"
  exit 1
fi

# Wait for API server to be ready
echo "Waiting for API server to be ready..."
echo "Using KUBECONFIG: $KUBECONFIG"
echo "Testing connectivity to: $SERVER_ADDRESS"

for i in $(seq 1 "$MAX_RETRIES"); do
  # Use kubectl to test API server readiness (more reliable than curl)
  if "$KUBECTL" cluster-info >/dev/null 2>&1; then
    echo "API server is ready!"
    break
  fi

  # Debug output every 10 attempts
  if [ $((i % 10)) -eq 1 ]; then
    echo "Debug info (attempt $i):"
    # Check if port is open
    if nc -zv 127.0.0.1 6443 2>&1 | grep -q succeeded; then
      echo "  - Port 6443 is open"
    else
      echo "  - Port 6443 is NOT open"
    fi
    # Try curl
    CURL_RESULT=$(curl -sk "$SERVER_ADDRESS/healthz" 2>&1 || echo "curl_failed")
    echo "  - Curl result: $CURL_RESULT"
  fi

  echo "Attempt $i/$MAX_RETRIES: API server not ready yet, waiting $RETRY_INTERVAL seconds..."
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "Error: API server did not become ready after $MAX_RETRIES attempts"
    echo "Final debug:"
    "$KUBECTL" cluster-info 2>&1 || true
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
