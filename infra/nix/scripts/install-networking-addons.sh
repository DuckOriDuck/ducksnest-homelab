#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG environment variable is required}"
: "${CALICO_VERSION:?CALICO_VERSION environment variable is required}"
: "${CLUSTER_CIDR:?CLUSTER_CIDR environment variable is required}"
: "${API_ENDPOINT:?API_ENDPOINT environment variable is required}"
: "${KUBE_PROXY_MANIFEST:?KUBE_PROXY_MANIFEST environment variable is required}"
: "${CALICO_PATCH:?CALICO_PATCH environment variable is required}"

log() {
  printf '[%s] %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)" "$*"
}

if ! kubectl --kubeconfig "$KUBECONFIG" get daemonset -n kube-system calico-node >/dev/null 2>&1; then
  log "Applying Calico manifest ${CALICO_VERSION}"
  curl -sSL "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
    | sed "s#192.168.0.0/16#${CLUSTER_CIDR}#g" \
    | kubectl --kubeconfig "$KUBECONFIG" apply -f -
else
  log "Calico daemonset already present; skipping"
fi

log "Patching Calico daemonset with repo overrides"
kubectl --kubeconfig "$KUBECONFIG" patch daemonset calico-node -n kube-system \
  --type merge --patch-file "$CALICO_PATCH"

if ! kubectl --kubeconfig "$KUBECONFIG" get daemonset -n kube-system kube-proxy >/dev/null 2>&1; then
  log "Applying kube-proxy daemonset"
  tmp_file=$(mktemp)
  trap 'rm -f "$tmp_file"' EXIT
  sed \
    -e "s#__CLUSTER_CIDR__#${CLUSTER_CIDR}#g" \
    -e "s#__APISERVER__#${API_ENDPOINT}#g" \
    "$KUBE_PROXY_MANIFEST" > "$tmp_file"
  kubectl --kubeconfig "$KUBECONFIG" apply -f "$tmp_file"
else
  log "kube-proxy daemonset already present; skipping"
fi
