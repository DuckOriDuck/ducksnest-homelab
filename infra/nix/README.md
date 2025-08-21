# NixOS Configuration for DuckNest Homelab

Modular NixOS configurations using Nix Flakes for the homelab infrastructure.

⚠️ **DEPRECATED**: EC2-related configurations have been deprecated. Use Ubuntu for EC2 instances instead.

## Structure

```
nix/
├── flake.nix                    # Host definitions and system architectures
├── hosts/                      # Host-specific configurations
│   ├── ec2-controlplane/       # DEPRECATED: Use Ubuntu for EC2
│   ├── ec2-jenkins/            # DEPRECATED: Use Ubuntu for EC2
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
| ~~**ec2-controlplane**~~ | ~~K8s Control Plane~~ | ~~ARM64~~ | ~~UEFI~~ | ~~CRI-O~~ (DEPRECATED) |
| ~~**ec2-jenkins**~~ | ~~CI/CD + VPN Server~~ | ~~ARM64~~ | ~~UEFI~~ | ~~Docker~~ (DEPRECATED) |
| **laptop-ultra** | Dev Workstation | x86_64 | UEFI | CRI-O |
| **laptop-old** | Worker Node | x86_64 | BIOS | CRI-O |