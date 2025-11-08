#!/bin/sh
set -e

if [ -f /opt/cni/bin/calico ] && [ ! -e /opt/cni/bin/calico-ipam ]; then
  ln -sf /opt/cni/bin/calico /opt/cni/bin/calico-ipam
  echo "Created symlink: /opt/cni/bin/calico-ipam -> /opt/cni/bin/calico"
elif [ -L /opt/cni/bin/calico-ipam ]; then
  echo "Symlink already exists: /opt/cni/bin/calico-ipam"
else
  echo "Warning: /opt/cni/bin/calico not found"
  exit 1
fi