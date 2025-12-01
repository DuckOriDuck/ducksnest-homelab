# Observability Stack

This directory contains the observability stack for the duck-hybrid cluster, including:
- **Prometheus**: Metrics collection and storage (via kube-prometheus-stack)
- **Loki**: Log aggregation and storage
- **Grafana**: Dashboards and visualization (included in kube-prometheus-stack)
- **Alertmanager**: Alert routing and management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐      ┌──────────────────┐              │
│  │   Prometheus    │◄─────┤  kube-state      │              │
│  │                 │      │  metrics         │              │
│  │  - Scrapes      │      └──────────────────┘              │
│  │    metrics      │                                         │
│  │  - Stores       │      ┌──────────────────┐              │
│  │    time series  │◄─────┤  kubelet/        │              │
│  │  - Evaluates    │      │  cAdvisor        │              │
│  │    alerts       │      └──────────────────┘              │
│  └────────┬────────┘                                         │
│           │                                                   │
│           │          ┌──────────────────┐                    │
│           └─────────►│  Alertmanager    │                    │
│                      │  - Routes alerts │                    │
│                      └──────────────────┘                    │
│                                                               │
│  ┌─────────────────┐                                         │
│  │   Loki          │                                         │
│  │                 │                                         │
│  │  - Stores logs  │                                         │
│  │  - Indexes      │                                         │
│  │  - Queries      │                                         │
│  └────────▲────────┘                                         │
│           │                                                   │
│           │                                                   │
│  ┌────────┴────────┐      ┌──────────────────┐              │
│  │   Grafana       │◄─────┤  Prometheus      │              │
│  │                 │      │  (datasource)    │              │
│  │  - Dashboards   │      └──────────────────┘              │
│  │  - Queries      │                                         │
│  │  - Alerts       │                                         │
│  └─────────────────┘                                         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         ▲
         │
         │ Push logs via HTTP
         │
┌────────┴────────────────────────────────────────────────────┐
│                      Host Nodes (NixOS)                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐      ┌──────────────────┐              │
│  │ node_exporter   │      │   promtail       │              │
│  │                 │      │                  │              │
│  │ - Exposes host  │      │ - Tails journald │              │
│  │   metrics       │      │ - Tails k8s logs │              │
│  │ - :9100         │      │ - Pushes to Loki │              │
│  └─────────────────┘      └──────────────────┘              │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Components

### Prometheus (kube-prometheus-stack)

**Purpose**: Metrics collection, storage, and alerting

**Endpoints**:
- Prometheus UI: `http://prometheus-prometheus.observability.svc.cluster.local:9090`
- Alertmanager UI: `http://prometheus-alertmanager.observability.svc.cluster.local:9093`

**What it monitors**:
- Node metrics from node_exporter on each host (:9100)
- Kubernetes metrics from kubelet and cAdvisor
- Pod and container metrics from kube-state-metrics
- Application metrics from `/metrics` endpoints (via ServiceMonitor CRDs)

**Configuration**:
- Retention: 15 days
- Storage: 50Gi PVC
- Scrape interval: 30s

### Loki

**Purpose**: Log aggregation and storage

**Endpoint**: `http://loki.observability.svc.cluster.local:3100`

**What it stores**:
- systemd journal logs from each node (via promtail)
- Kubernetes container logs from `/var/log/containers` (via promtail)

**Configuration**:
- Retention: 31 days (744h)
- Storage: 100Gi PVC
- Deployment: Single binary mode

### Grafana

**Purpose**: Visualization and dashboards

**Endpoint**:
- Internal: `http://prometheus-grafana.observability.svc.cluster.local:80`
- NodePort: `http://<node-ip>:30300`

**Credentials**:
- Username: `admin`
- Password: `admin` (change this!)

**Pre-installed Dashboards**:
- Node Exporter Full (ID: 1860) - Host metrics
- Kubernetes Cluster Monitoring (ID: 7249) - K8s overview
- Loki Dashboard (ID: 13639) - Log exploration

**Data Sources**:
- Prometheus: `http://prometheus-prometheus:9090`
- Loki: `http://loki:3100`

## Host Configuration (NixOS)

On each worker node, enable the observability role in your NixOS configuration:

```nix
{
  services.observability = {
    enable = true;

    # node_exporter settings
    nodeExporter = {
      enable = true;
      port = 9100;
    };

    # promtail settings
    promtail = {
      enable = true;
      port = 9080;
      lokiUrl = "http://loki.observability.svc.cluster.local:3100";
    };

    # Cluster metadata
    clusterName = "duck-hybrid";
    environment = "homelab";
  };
}
```

This will:
1. Start node_exporter on port 9100 to expose host metrics
2. Start promtail on port 9080 to collect and forward logs
3. Configure promtail to send logs to Loki in the cluster

## Accessing Services

### Grafana

**Via kubectl port-forward**:
```bash
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# Access at http://localhost:3000
```

**Via NodePort** (if on Tailscale network):
```bash
# Access at http://<node-tailscale-ip>:30300
```

### Prometheus

```bash
kubectl port-forward -n observability svc/prometheus-prometheus 9090:9090
# Access at http://localhost:9090
```

### Loki

```bash
kubectl port-forward -n observability svc/loki 3100:3100
# Query logs: http://localhost:3100/loki/api/v1/query
```

### Alertmanager

```bash
kubectl port-forward -n observability svc/prometheus-alertmanager 9093:9093
# Access at http://localhost:9093
```

## Customization

### Update Node Exporter Targets

Edit [prometheus-app.yaml](manifests/prometheus-app.yaml) and update the `additionalScrapeConfigs` section:

```yaml
additionalScrapeConfigs:
  - job_name: 'node-exporter-hosts'
    static_configs:
      - targets:
        - '10.0.1.10:9100'  # Worker node 1
        - '10.0.1.11:9100'  # Worker node 2
        labels:
          cluster: duck-hybrid
```

### Add Custom Dashboards

Add dashboards to Grafana via:

1. **Grafana UI**: Import dashboard by ID
2. **Git**: Add dashboard JSON to `prometheus-app.yaml` under `grafana.dashboards.default`

### Add Application Metrics

Create a ServiceMonitor to scrape application metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: observability
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
```

## Troubleshooting

**Check Prometheus targets**:
```bash
kubectl port-forward -n observability svc/prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

**Check Loki ingestion**:
```bash
kubectl logs -n observability deployment/loki -f
```

**Check promtail on nodes**:
```bash
# On a NixOS worker node
systemctl status promtail
journalctl -u promtail -f
```

**Check Grafana datasources**:
```bash
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# Visit http://localhost:3000/datasources
```

## Maintenance

**Update Helm chart versions**:
Edit the `targetRevision` field in each Application manifest and commit to Git.

**Scale Loki replicas** (if moving from single binary):
Edit [loki-app.yaml](manifests/loki-app.yaml) and change `deploymentMode` and replica counts.

**Increase retention**:
Edit retention settings in the Application manifests and commit to Git.
