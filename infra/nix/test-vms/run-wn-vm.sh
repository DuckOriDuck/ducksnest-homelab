#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VM_SCRIPT="$BASE_DIR/result-wn/bin/run-ducksnest-test-worker-node-vm"
TAP_DEVICE="${TAP_DEVICE:-tap1}"
MAC_ADDRESS="${MAC_ADDRESS:-52:54:00:12:34:02}"

# Replace user-mode networking with TAP networking in the VM script
sed 's| -net nic,netdev=user\.0,model=virtio -netdev user,id=user\.0,"[^"]*"| -net nic,netdev=tap1,model=virtio,macaddr='"${MAC_ADDRESS}"' -netdev tap,id=tap1,ifname='"${TAP_DEVICE}"',script=no,downscript=no|g' "$VM_SCRIPT" | bash
