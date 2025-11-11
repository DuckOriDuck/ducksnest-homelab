#!/usr/bin/env bash
set -euo pipefail

# Apply one or more Kubernetes manifest files/directories
#
# Usage: apply-manifests.sh <kubectl_path> <manifest>...
#   <kubectl_path>  - absolute path to kubectl binary
#   <manifest>      - file or directory (glob) to apply. Directories are
#                    traversed and every *.yaml file is applied in lexical order.

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <kubectl_path> <manifest>..." >&2
  exit 1
fi

KUBECTL="$1"
shift

apply_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Warning: manifest '$file' does not exist, skipping" >&2
    return
  fi
  echo "Applying manifest: $file"
  "$KUBECTL" apply -f "$file"
}

for entry in "$@"; do
  if [ -d "$entry" ]; then
    shopt -s nullglob
    for file in "$entry"/*.yaml; do
      apply_file "$file"
    done
    shopt -u nullglob
  else
    apply_file "$entry"
  fi
done
