# Kubernetes Manifests

이 디렉토리는 클러스터에 수동으로 적용할 Kubernetes manifest 파일을 포함합니다.

## kube-proxy

Service networking을 위한 kube-proxy DaemonSet입니다.

### 적용 방법

```bash
# RBAC이 이미 있는지 확인 (infra/nix/k8s/rbac/03-kube-proxy.yaml)
kubectl get serviceaccount kube-proxy -n kube-system

# kube-proxy 배포
kubectl apply -f k8s/manifests/kube-proxy.yaml

# 확인
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl get daemonset -n kube-system kube-proxy
```

### 설정

- **Image**: `registry.k8s.io/kube-proxy:v1.34.2`
- **Mode**: iptables
- **Cluster CIDR**: 10.244.0.0/16

### 문제 해결

```bash
# kube-proxy 로그 확인
kubectl logs -n kube-system -l k8s-app=kube-proxy

# kube-proxy가 iptables 규칙을 생성했는지 확인 (노드에서)
sudo iptables -t nat -L KUBE-SERVICES
```