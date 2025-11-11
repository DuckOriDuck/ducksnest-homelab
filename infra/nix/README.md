# NixOS Infrastructure Architecture
## WARNING: THIS DOCUMENT IS ROUGH DRAFT WROTE WITH CLUADE CODE! I WILL BE MAKING MAJOUR CHANGES ASAP
This document is still under heavy revision, and major updates will be made soon.
Currently, the configurations are set with firebat-laptop as the control plane, and most parameters are tuned for the test environment.
This setup was intentional for debugging and validation purposes.

The bare-metal Calico installation issue is fully resolved now.
## Overview

This homelab uses a modular NixOS Flake structure to declaratively manage a Kubernetes cluster with an **EC2 control plane (AWS)** and **on-premise worker nodes**. The infrastructure is designed with composability, reproducibility, and security in mind.

**Architecture**: Hybrid cloud setup where the control plane runs on AWS EC2 (t3.medium) and connects to on-premise worker nodes via Tailscale VPN. All nodes are configured declaratively using NixOS modules.

## Directory Structure

```plaintext
infra/nix/
├── flake.nix                    # Main entry point - defines all hosts and their roles
├── modules/                     # Reusable NixOS modules
│   ├── boot/                   # Boot configuration modules
│   │   ├── boot-bios.nix      # BIOS/Legacy boot settings
│   │   ├── boot-uefi.nix      # UEFI/systemd-boot settings
│   │   └── ec2-modules.nix    # EC2-specific boot configuration
│   ├── certs/                  # Certificate management
│   │   └── ca.nix             # K8Nix certToolkit configuration for TLS
│   ├── common/                 # Common system configurations
│   │   ├── base.nix           # Base packages and settings
│   │   ├── security.nix       # Security hardening
│   │   └── users.nix          # User management
│   ├── roles/                  # Kubernetes role-specific modules
│   │   ├── control-plane.nix  # K8s control plane components
│   │   ├── worker-node.nix    # K8s worker node setup
│   │   ├── tailscale-client.nix # Tailscale VPN client
│   │   └── observability.nix  # Monitoring and logging
│   └── kubernetes-bootstrap.nix # Custom module for K8s bootstrap tasks
├── hosts/                       # Per-host configurations
│   ├── ec2-controlplane/       # EC2 control plane (AWS t3.medium)
│   ├── laptop-firebat/         # Worker node (on-prem, Intel N100)
│   ├── laptop-ultra/           # Worker node (on-prem, Intel i5-8250U)
│   ├── laptop-old/             # Worker node (on-prem, Intel i3-M 330)
│   ├── test-controlplane/      # Test VM control plane
│   └── test-worker-node/       # Test VM worker node
├── k8s/                         # Kubernetes manifests and scripts
│   ├── scripts/                # Bootstrap scripts
│   ├── rbac/                   # RBAC manifests
│   ├── addons/                 # K8s addons (calico-node)
│   └── calico/                 # Calico CNI configuration
├── secrets/                     # Age-encrypted secrets
│   ├── certs/                  # Encrypted TLS certificates
│   └── ssh-host-keys/          # SSH host public keys for decryption
└── test-vms/                    # Scripts to build and run test VMs
```

## Key Components

### 1. Flake Structure ([flake.nix](infra/nix/flake.nix))

The flake is the heart of the infrastructure, defining:

- **Inputs**:
  - `nixpkgs` (25.05) - Main package source
  - `nixpkgs-unstable` - Bleeding edge packages
  - `nixos-generators` - VM/image generation
  - `agenix` - Age-based secret encryption
  - `k8nix-cert-management` - Kubernetes TLS certificate toolkit

- **Host Configurations**: Each host is defined with:
  - System architecture (x86_64-linux)
  - Kubernetes role (control-plane or worker)
  - Specific hardware and configuration modules

- **Apps**: Flake apps for certificate management:
  - `nix run .#certs-recreate` - Regenerate all TLS certificates
  - `nix run .#certs-recreate-test` - Regenerate test environment certs only

**Host to Role Mapping**:

```nix
{
  ec2-controlplane = "control-plane";  # Primary control plane (AWS)
  laptop-firebat = "worker";           # On-prem worker
  laptop-ultra = "worker";             # On-prem worker
  laptop-old = "worker";               # On-prem worker
  test-controlplane = "control-plane"; # Test VM
  test-worker-node = "worker";         # Test VM
}
```

### 2. Certificate Management ([modules/certs/ca.nix](infra/nix/modules/certs/ca.nix))

This project uses **K8Nix certToolkit** for declarative TLS certificate management, integrated with **agenix** for encryption. All certificates are generated from a single CA and distributed securely to nodes.

**Key Features**:

- **Single CA**: All K8s components trust one Certificate Authority
- **Role-based certificates**: Control plane gets additional etcd and apiserver certs
- **Age encryption**: Private keys are encrypted using SSH keys, only the owning host can decrypt
- **Reproducible**: `nix run .#certs-recreate` regenerates all certificates deterministically
- **Version controlled**: Encrypted certificates live in Git (`secrets/certs/`)

**Certificate Types**:

Common to all nodes:

- `kubelet` - Node identity certificate
- `calico-cni` - CNI plugin authentication

Control plane only:

- `etcd-server`, `etcd-peer`, `etcd-client` - etcd cluster certificates
- `kube-apiserver` - API server with multiple SANs (kubernetes.default.svc, etc.)
- `kube-apiserver-kubelet-client` - API server to kubelet communication
- `kube-apiserver-etcd-client` - API server to etcd communication
- `kube-controller-manager` - Controller manager identity
- `kube-scheduler` - Scheduler identity
- `kube-admin` - Admin user certificate (system:masters group)
- `service-account` - Service account token signing key

**How it works**:

1. Each host has a dedicated SSH key pair for certificate decryption
2. `certToolkit.owningHostKey` points to the host's public key
3. When certificates are regenerated, they're encrypted with the operator's key + each host's key
4. At boot, agenix decrypts certificates using the host's private SSH key
5. NixOS modules reference certificates via `config.certToolkit.cas.k8s.certs.<name>.path`

See [docs/certtoolkit-k8s.md](infra/nix/docs/certtoolkit-k8s.md) for detailed usage.

### 3. Kubernetes Bootstrap Module ([modules/kubernetes-bootstrap.nix](infra/nix/modules/kubernetes-bootstrap.nix))

A custom NixOS module that provides a declarative way to define Kubernetes cluster initialization tasks as systemd oneshot services.

**Purpose**: Automate cluster bootstrap tasks like generating kubeconfigs, applying RBAC rules, installing CRDs, and deploying CNI components.

**How it works**:

1. Define tasks in the `kubernetes.bootstrap.tasks` attribute set
2. Each task becomes a systemd service named `k8s-bootstrap-<name>`
3. Tasks can depend on each other using the `after` attribute
4. Services run once and remain after exit (Type=oneshot, RemainAfterExit=true)

**Task Configuration**:

```nix
kubernetes.bootstrap.tasks.<name> = {
  description = "Human-readable description";
  script = "/path/to/script.sh";        # Bash script to execute
  args = [ "arg1" "arg2" ];             # Script arguments
  after = [ "dependency.service" ];     # Run after these units
  environment = { VAR = "value"; };     # Environment variables
  preStart = "echo 'preparing...'";     # Commands before main script
};
```

**Example Usage** (from [control-plane.nix:187-301](infra/nix/modules/roles/control-plane.nix#L187-L301)):

- `generate-kubeconfig` - Creates admin kubeconfig file
- `generate-cni-kubeconfig` - Creates CNI plugin kubeconfig
- `bootstrap-rbac` - Applies RBAC manifests
- `calico-crds` - Installs Calico CRDs
- `calico-ip-pool` - Configures Calico IP pool
- `calico-node` - Deploys Calico DaemonSet

Tasks execute in dependency order at system boot, ensuring the cluster is ready without manual intervention.

### 4. Role Modules

Role modules define the specific configuration for different Kubernetes node types. They are composable and can be imported into host configurations.

#### Control Plane ([modules/roles/control-plane.nix](infra/nix/modules/roles/control-plane.nix))

Configures a node to run Kubernetes control plane components.

**Components**:

- **etcd** - Clustered key-value store for Kubernetes state
  - Listens on `https://127.0.0.1:2379`
  - Uses TLS certificates from certToolkit
- **kube-apiserver** - Kubernetes API server
  - Binds to 0.0.0.0:6443
  - Configured with multiple SANs for flexibility
  - Uses service account key for token signing
- **kube-controller-manager** - Manages controllers (replication, endpoints, etc.)
- **kube-scheduler** - Schedules pods to nodes
- **kubelet** - Runs on control plane but tainted with NoSchedule
  - Taint: `node-role.kubernetes.io/control-plane=true:NoSchedule`
- **Calico CNI** - Container networking
  - VXLAN backend for cross-subnet communication
  - Integrated with Kubernetes datastore
- **CoreDNS** - Cluster DNS (via `addons.dns.enable`)

**CNI Configuration**:

- Uses Calico CNI plugin with IPAM
- CNI config copied to `/var/lib/cni/net.d/`
- Calico kubeconfig generated for API access
- Calico node DaemonSet deployed via bootstrap tasks

**Bootstrap Tasks** (see section 3):

1. Generate admin kubeconfig
2. Generate CNI kubeconfig
3. Setup calico-ipam symlink
4. Bootstrap RBAC (kubelet, kube-proxy, CNI permissions)
5. Install Calico CRDs
6. Configure Calico IP pool (10.244.0.0/16)
7. Apply Calico RBAC
8. Deploy Calico node DaemonSet

**Packages**: kubernetes, helm, kustomize, k9s, calicoctl, awscli2, monitoring tools

#### Worker Node ([modules/roles/worker-node.nix](infra/nix/modules/roles/worker-node.nix))

Configures a node to run workload pods only (no control plane components).

**Components**:

- **kubelet** - Registers with the control plane and runs pods
  - `unschedulable = false` - Ready to accept workloads
  - Connects to remote API server
  - Uses TLS certificates from certToolkit
- **Calico CNI** - Same CNI setup as control plane for consistent networking
- **containerd** - Container runtime

**Key Differences from Control Plane**:

- No etcd, apiserver, controller-manager, scheduler
- `masterAddress` points to control plane hostname or IP
- Kubelet kubeconfig points to remote API server
- Only generates CNI kubeconfig (no admin kubeconfig)
- Simplified bootstrap tasks (CNI setup only)

**Master Address Logic**:

```nix
masterAddress =
  if config.networking.hostName == "ducksnest-test-worker-node"
  then "ducksnest-test-controlplane"
  else "ducksnest-controlplane";  # Points to EC2 control plane
```

For test VMs, uses internal IP (10.100.0.2). For production workers, connects to EC2 control plane via Tailscale hostname (`ducksnest-controlplane`).

#### Tailscale Client ([modules/roles/tailscale-client.nix](infra/nix/modules/roles/tailscale-client.nix))

Simple module that enables Tailscale VPN client on a node. This allows nodes to communicate across different networks (on-prem and cloud) using Tailscale's mesh VPN.

**Features**:

- Enables `services.tailscale`
- Adds `tailscale` package to system packages
- Nodes can join Tailscale network with `tailscale up`

**Use Case**: Connect on-premise worker nodes to EC2 control plane securely without exposing Kubernetes API to public internet.

#### Observability ([modules/roles/observability.nix](infra/nix/modules/roles/observability.nix))

Provides an optional monitoring stack for cluster and node metrics.

**Components**:

- **Prometheus** (port 9090) - Metrics collection and storage
  - Auto-discovers Kubernetes nodes and pods
  - Scrapes node-exporter metrics from all nodes
- **Node Exporter** (port 9100) - Exports hardware and OS metrics
  - Enabled collectors: systemd, filesystem, network, CPU, memory, disk, processes
- **Grafana** (port 3000, optional) - Metrics visualization dashboard
  - Default credentials: admin/admin (change in production!)

**Configuration**:

```nix
services.observability = {
  enable = true;
  prometheus.enable = true;     # Default: true
  nodeExporter.enable = true;   # Default: true
  grafana.enable = false;       # Default: false
};
```

**Kubernetes Integration**: Prometheus uses Kubernetes service discovery to automatically find and monitor all nodes and pods in the cluster.

### 5. Kubernetes Manifests and Scripts ([k8s/](infra/nix/k8s/))

Contains Kubernetes manifests and bash scripts used during cluster bootstrap. These are referenced by the bootstrap module tasks.

#### Scripts ([k8s/scripts/](infra/nix/k8s/scripts/))

Bootstrap automation scripts executed by systemd services:

- **generate-admin-kubeconfig.sh** - Creates admin kubeconfig with cluster-admin permissions
  - Args: output path, CA cert, client cert, client key, API server URL, cluster name, user name
- **generate-cni-kubeconfig.sh** - Creates CNI plugin kubeconfig for Calico
  - Args: same as admin kubeconfig, but uses CNI-specific certificates
- **setup-calico-ipam.sh** - Creates symlink for calico-ipam binary
  - Links `/opt/cni/bin/calico-ipam` to `/run/current-system/sw/bin/calico-ipam`
- **bootstrap-rbac.sh** - Applies all RBAC manifests with retry logic
  - Waits for API server to be ready
  - Applies manifests in order with error handling
- **apply-manifests.sh** - Generic manifest applier used for CRDs and addons
  - Validates manifests before applying
  - Used by multiple bootstrap tasks

#### RBAC Manifests ([k8s/rbac/](infra/nix/k8s/rbac/))

Kubernetes RBAC configurations applied during bootstrap:

- **00-kube-apiserver-to-kubelet.yaml** - ClusterRole for API server to access kubelet API
  - Permissions: nodes/proxy, nodes/stats, nodes/log, nodes/spec, nodes/metrics
- **01-node-authorizer.yaml** - ClusterRoleBinding for Node authorizer
  - Binds `system:node` group to `system:node` role
- **02-kubelet-api-admin.yaml** - ClusterRoleBinding for kubelet API access
  - Grants kube-apiserver user access to kubelet API
- **03-kube-proxy.yaml** - ServiceAccount and ClusterRoleBinding for kube-proxy
  - Even though kube-proxy is disabled, this provides the RBAC foundation
- **04-calico-cni.yaml** - ServiceAccount and ClusterRole for Calico CNI plugin
  - Permissions: pods, nodes, namespaces get/list/watch
- **05-calico-node.yaml** - Comprehensive RBAC for Calico node DaemonSet
  - Multiple ClusterRoles for node management, pod networking, and IPAM

#### Calico Configuration ([k8s/calico/](infra/nix/k8s/calico/))

- **10-calico.conflist** - CNI network configuration (copied to `/var/lib/cni/net.d/`)
- **ip-pool.yaml** - IPPool resource defining pod CIDR and VXLAN encapsulation

#### Addons ([k8s/addons/](infra/nix/k8s/addons/))

- **calico-node.yaml** - DaemonSet for Calico node agent
  - Runs on all nodes (including control plane despite NoSchedule taint)
  - Manages pod networking, BGP routing, and network policies

### 6. Common Modules ([modules/common/](infra/nix/modules/common/))

Shared configuration applied to all hosts:

- **base.nix** - System-wide settings
  - Timezone: Asia/Seoul, Locale: en_US.UTF-8
  - Enables Nix flakes and experimental features
  - Auto-optimize Nix store, weekly garbage collection (14d retention)
  - NetworkManager enabled, firewall with SSH allowed
  - Age identity path for secret decryption
  - Shell aliases for convenience

- **security.nix** - Security hardening settings
  - SSH configuration, fail2ban, etc.

- **users.nix** - User account management
  - Creates operator accounts with sudo access

### 7. Boot Modules ([modules/boot/](infra/nix/modules/boot/))

Boot configuration for different platforms:

- **boot-uefi.nix** - UEFI boot with systemd-boot
  - For modern hardware (laptop-ultra, laptop-firebat)
- **boot-bios.nix** - Legacy BIOS boot with GRUB
  - For older hardware (laptop-old)
- **ec2-modules.nix** - EC2-specific boot configuration
  - For cloud instances

### 8. Test VMs ([test-vms/](infra/nix/test-vms/))

Scripts for testing the Kubernetes setup in local VMs using QEMU:

- **build-vms.sh** - Builds test VM images for control plane and worker node
  - Creates QEMU VM images from NixOS configurations
  - Generates disk images with proper sizing
  - Sets up networking configuration for VM communication

- **run-cp-vm.sh** - Launches control plane VM
  - 2GB RAM, 2 CPUs
  - Network: 10.100.0.2/24 (static IP)
  - Forwards port 6443 for API server access

- **run-wn-vm.sh** - Launches worker node VM
  - 2GB RAM, 2 CPUs
  - Network: 10.100.0.3/24 (static IP)
  - Connects to control plane at 10.100.0.2

- **setup-internet.sh** - Configures NAT and routing for VMs
  - Enables IP forwarding
  - Sets up iptables NAT rules
  - Allows VMs to access internet through host

**Usage**:

```bash
cd infra/nix/test-vms
./build-vms.sh              # Build VM images
./setup-internet.sh         # Setup networking (run once)
./run-cp-vm.sh              # Start control plane
./run-wn-vm.sh              # Start worker node
```

### 9. Secrets Management ([secrets/](infra/nix/secrets/))

Uses **agenix** for age-encrypted secret management:

- **secrets/certs/** - Age-encrypted TLS certificates
  - `ca/` - Certificate Authority
  - `derived/<hostname>/` - Per-host certificates
  - Only encrypted `.age` files are committed to Git

- **secrets/ssh-host-keys/** - SSH host public keys
  - Used by agenix to encrypt secrets for specific hosts
  - Each host can only decrypt its own secrets

**How it works**:

1. Each host has an SSH key pair for secret decryption
2. Secrets are encrypted with multiple recipient keys (operator + target hosts)
3. At boot, `age.secrets` modules decrypt secrets using `/root/.ssh/ducksnest_cert_mng_key`
4. Decrypted secrets are mounted to `/run/agenix/` with proper permissions
5. Services reference decrypted paths (e.g., certificate files)

### 10. Host Configurations ([hosts/](infra/nix/hosts/))

Each host directory contains:

- **configuration.nix** - Host-specific configuration
  - Imports role modules (control-plane, worker-node, etc.)
  - Sets hostname, networking, hardware-specific settings
  - Defines which optional modules to enable (observability, tailscale)

- **hardware-configuration.nix** - Auto-generated hardware config
  - Filesystems, kernel modules, boot settings
  - Generated by `nixos-generate-config`

**Host Overview**:

- `ec2-controlplane` - **Primary control plane** (AWS t3.medium, 2 vCPU, 4GB RAM)
  - Runs etcd, kube-apiserver, controller-manager, scheduler, kubelet
  - Manages cluster state and API access
  - Connected via Tailscale VPN to on-prem workers
- `laptop-firebat` - Worker node (Intel N100, 4 cores @ 3.40 GHz, 15.4 GiB RAM)
- `laptop-ultra` - Worker node (Intel i5-8250U, 8 cores @ 3.40 GHz, 15.5 GiB RAM, NVIDIA GTX 1050)
- `laptop-old` - Worker node (Intel i3-M 330, 4 cores @ 2.13 GHz, 1.9 GiB RAM, legacy hardware)
- `test-controlplane` / `test-worker-node` - Test VMs for local development and testing

## How It All Works Together

1. **Build Time**:
   - Flake defines all hosts with their roles
   - Certificates are generated with `nix run .#certs-recreate`
   - Encrypted certs are committed to Git

2. **Deployment**:
   - `nixos-rebuild switch --flake .#<hostname>` on target machine
   - NixOS builds system closure with all modules
   - Agenix decrypts certificates using host SSH key

3. **Boot Time**:
   - Systemd starts services in dependency order
   - Control plane: etcd → kube-apiserver → controller/scheduler → kubelet
   - Bootstrap tasks run: generate kubeconfigs → apply RBAC → install CNI
   - Worker nodes: kubelet starts and registers with API server
   - Calico node DaemonSet deploys, pod networking becomes available

4. **Runtime**:
   - Pods scheduled across nodes
   - Calico provides VXLAN networking between nodes
   - Tailscale VPN connects on-prem and cloud nodes
   - Prometheus scrapes metrics from all nodes
