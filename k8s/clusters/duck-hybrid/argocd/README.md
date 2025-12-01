# Argo CD Bootstrap

This directory contains the bootstrap manifests for Argo CD using the "app of apps" pattern.

## Initial Installation

1. **Install Argo CD:**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Apply custom Argo CD configuration:**
   ```bash
   kubectl apply -f k8s/clusters/duck-hybrid/argocd/install.yaml
   ```

3. **Wait for Argo CD to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
   ```

4. **Get initial admin password:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   echo
   ```

5. **Access Argo CD UI:**

   Via port-forward:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

   Or via NodePort (if on Tailscale network):
   ```bash
   # Access at https://<node-tailscale-ip>:30443
   ```

6. **Deploy the root application:**
   ```bash
   # Update the repoURL in root-application.yaml to point to your Git repository
   # Then apply:
   kubectl apply -f k8s/clusters/duck-hybrid/argocd/root-application.yaml
   ```

## Structure

```
argocd/
├── README.md              # This file
├── install.yaml           # Argo CD custom configuration
└── root-application.yaml  # Root app-of-apps Application

apps/
├── observability/
│   ├── observability-app.yaml    # Observability stack Application
│   └── manifests/                # Prometheus, Loki, Grafana Applications
├── databases/
│   ├── databases-app.yaml        # Databases Application
│   └── manifests/                # Postgres and other DB Applications
└── workloads/
    ├── workloads-app.yaml        # Workloads Application
    └── manifests/                # Application Helm charts
```

## Updating Applications

All changes to applications should be made via Git commits to this repository. Argo CD will automatically:
- Detect changes in the Git repository
- Sync the changes to the cluster (if auto-sync is enabled)
- Self-heal any manual changes made directly to the cluster

## Troubleshooting

**Check Argo CD logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

**Check application sync status:**
```bash
kubectl get applications -n argocd
```

**Force sync an application:**
```bash
kubectl patch application <app-name> -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```

**Delete and recreate root application:**
```bash
kubectl delete application root -n argocd
kubectl apply -f k8s/clusters/duck-hybrid/argocd/root-application.yaml
```
