#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VM_SCRIPT="$BASE_DIR/result-cp/bin/run-ducksnest-test-controlplane-vm"
TAP_DEVICE="${TAP_DEVICE:-tap0}"
MAC_ADDRESS="${MAC_ADDRESS:-52:54:00:12:34:01}"

# Replace user-mode networking with TAP networking in the VM script
# Pattern: -net nic,netdev=user.0,model=virtio -netdev user,id=user.0,"$QEMU_NET_OPTS"
# Replace: -net nic,netdev=tap0,model=virtio,mac=X -netdev tap,id=tap0,ifname=Y,script=no,downscript=no

sed 's| -net nic,netdev=user\.0,model=virtio -netdev user,id=user\.0,"[^"]*"| -net nic,netdev=tap0,model=virtio,macaddr='"${MAC_ADDRESS}"' -netdev tap,id=tap0,ifname='"${TAP_DEVICE}"',script=no,downscript=no|g' "$VM_SCRIPT" | bash
