# NixOS Configuration for DuckNest Homelab

Modular NixOS configurations using Nix Flakes for the homelab infrastructure.

## Structure

```
nix/
├── flake.nix                    # Host definitions and system architectures
├── hosts/                      # Host-specific configurations
│   ├── ec2-controlplane/       # Kubernetes control plane (AWS EC2)
│   ├── ec2-jenkins/            # Jenkins + Headscale server (AWS EC2)
│   ├── laptop-ultra/           # Development workstation
│   └── laptop-old/             # Basic worker node
└── modules/                    # Modular configuration components
    ├── common/                 # Shared configurations
    │   ├── base.nix           # System basics (time, locale, networking)
    │   ├── users.nix          # Common user accounts
    │   ├── security.nix       # Security hardening
    │   ├── boot-uefi.nix      # UEFI boot (systemd-boot)
    │   └── boot-bios.nix      # BIOS boot (GRUB)
    └── roles/                 # Role-based configurations
        ├── control-plane.nix  # Kubernetes control plane
        ├── worker-node.nix    # Kubernetes worker node
        ├── jenkins.nix        # Jenkins CI/CD server
        ├── headscale-server.nix # Headscale VPN server
        └── tailscale-client.nix # Tailscale VPN client
```

## Hosts

| Host | Role | Architecture | Boot | Container Runtime |
|------|------|-------------|------|------------------|
| **ec2-controlplane** | K8s Control Plane | ARM64 | UEFI | CRI-O |
| **ec2-jenkins** | CI/CD + VPN Server | ARM64 | UEFI | Docker |
| **laptop-ultra** | Dev Workstation | x86_64 | UEFI | CRI-O |
| **laptop-old** | Worker Node | x86_64 | BIOS | CRI-O |

## Technology Stack

- **Kubernetes**: kubeadm + Flannel CNI + CRI-O runtime
- **VPN**: Headscale (server) + Tailscale (clients)
- **CI/CD**: Jenkins with Docker builds
- **Monitoring**: Prometheus + Node Exporter
- **Boot**: UEFI (systemd-boot) or BIOS (GRUB)

## Quick Start

### 1. Build and Deploy

```bash
# Build locally
sudo nixos-rebuild switch --flake .#laptop-ultra
sudo nixos-rebuild switch --flake .#laptop-old

# Deploy remotely
nixos-rebuild switch --flake .#ec2-controlplane --target-host root@controlplane
nixos-rebuild switch --flake .#ec2-jenkins --target-host root@jenkins
```

### 2. Initialize Kubernetes

**Control Plane** (automatically via systemd):
```bash
sudo systemctl status kubeadm-init
sudo journalctl -u kubeadm-init -f
```

**Join Workers**:
```bash
# On control plane
sudo kubeadm token create --print-join-command

# Run the join command on worker nodes
```

### 3. Setup VPN

**Headscale Server** (on ec2-jenkins):
```bash
headscale users create homelab
headscale --user homelab preauthkeys create --reusable --expiration 24h
```

**Tailscale Clients**:
```bash
sudo tailscale up --login-server=https://headscale.yourdomain.com --authkey=YOUR_KEY
```

## Configuration Philosophy

Each `configuration.nix` explicitly imports all required modules:

```nix
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix          # System basics
    ../../modules/common/users.nix         # User accounts
    ../../modules/common/boot-uefi.nix     # Boot configuration
    ../../modules/roles/control-plane.nix  # Role-specific config
    ../../modules/roles/tailscale-client.nix # VPN client
  ];
  
  # Host-specific overrides
  networking.hostName = "my-host";
  boot.loader.grub.device = "/dev/sda";  # BIOS only
}
```

**Benefits:**
- Each host configuration is self-contained
- No hidden dependencies via flake injections
- Clear module hierarchy
- Easy to understand and maintain

## Common Operations

### Updates
```bash
nix flake update
sudo nixos-rebuild switch --flake .#hostname
```

### Cleanup
```bash
sudo nix-collect-garbage -d
```

### Troubleshooting
```bash
# Test without switching
sudo nixos-rebuild test --flake .#hostname

# Check what will be built
nix build .#nixosConfigurations.hostname.config.system.build.toplevel --dry-run

# Verbose output
sudo nixos-rebuild switch --flake .#hostname --show-trace
```

## Module Details

### Common Modules
- **base.nix**: Time zone, locale, networking, Nix settings
- **users.nix**: `oriduckduck`, `remoteduckduck`, `duck` users
- **security.nix**: Firewall, SSH hardening
- **boot-*.nix**: UEFI (systemd-boot) or BIOS (GRUB) configurations

### Role Modules
- **control-plane.nix**: kubeadm init, Prometheus, Flannel
- **worker-node.nix**: Desktop environment, development tools
- **jenkins.nix**: CI/CD server with Docker builds
- **headscale-server.nix**: VPN coordination server
- **tailscale-client.nix**: VPN client with auto-connect

## Security

- SSH key-based authentication only
- Firewall enabled by default
- VPN-first networking with Tailscale
- CRI-O security features for Kubernetes
- Separate container runtimes (CRI-O for K8s, Docker for CI/CD)

---

**Architecture**: Each host imports exactly what it needs • No complex flake magic • Clear dependencies