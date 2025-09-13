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

## Usage

### Remote Build & Deploy from GitHub

```bash
# GitHub flakes need dir= parameter when flake.nix is in subdirectory
sudo nixos-rebuild switch --flake github:DuckOriDuck/ducksnest-homelab?dir=infra/nix#laptop-ultra

# Using different branch
sudo nixos-rebuild switch --flake github:DuckOriDuck/ducksnest-homelab/main?dir=infra/nix#laptop-old

# Test build without applying
sudo nixos-rebuild build --flake github:DuckOriDuck/ducksnest-homelab?dir=infra/nix#laptop-ultra
```

### Local Development

```bash
# Clone and build locally
git clone https://github.com/DuckOriDuck/ducksnest-homelab.git
cd ducksnest-homelab/infra/nix

# Build specific host
sudo nixos-rebuild switch --flake .#laptop-ultra

# Test build without applying
sudo nixos-rebuild build --flake .#laptop-ultra

# Build all hosts to verify
nix flake check
```

### Validation & Testing

```bash
# Check all configurations build successfully
nix flake check

# Build specific host without applying
nix build .#nixosConfigurations.laptop-ultra.config.system.build.toplevel

# Build all hosts
nix build .#nixosConfigurations.laptop-ultra.config.system.build.toplevel
nix build .#nixosConfigurations.laptop-old.config.system.build.toplevel

# Show flake info
nix flake show

# Update flake inputs
nix flake update
```

### Host Selection

- `laptop-ultra`: Development workstation with full features
- `laptop-old`: Minimal worker node configuration