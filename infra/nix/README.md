# NixOS Configuration for DuckNest Homelab

This directory contains NixOS configurations for the homelab environment using Nix Flakes.

## Structure

```
nix/
├── flake.nix                    # Main flake configuration
├── flake.lock                  # Lock file for reproducible builds
├── hosts/
│   ├── laptopA/                # Development workstation
│   │   ├── configuration.nix   # System configuration
│   │   ├── hardware-configuration.nix  # Hardware-specific settings
│   │   └── home.nix           # Home Manager configuration
│   └── laptopB/                # Server/production workstation
│       ├── configuration.nix   # System configuration
│       ├── hardware-configuration.nix  # Hardware-specific settings
│       └── home.nix           # Home Manager configuration
└── README.md                   # This file
```

## Host Profiles

### LaptopA - Development Workstation
- **Purpose**: Primary development environment
- **Features**: 
  - Full desktop environment (GNOME)
  - Development tools (VS Code, IDEs)
  - Container runtime (Docker)
  - Kubernetes tools (kubectl, helm, k9s)
  - Infrastructure tools (Terraform, Ansible)
  - Monitoring tools (Prometheus, Grafana)
  - Development databases (PostgreSQL, Redis)

### LaptopB - Server/Production Workstation  
- **Purpose**: Server-oriented environment for production services
- **Features**:
  - Minimal desktop environment
  - Nginx reverse proxy
  - Production monitoring (Prometheus, Grafana, Node Exporter)
  - Docker with production settings
  - PostgreSQL and Redis servers
  - Enhanced security (Fail2ban, AppArmor)
  - Server management tools

## Initial Setup

### 1. Hardware Configuration
Before applying configurations, generate hardware-specific settings:

```bash
# On target machine
sudo nixos-generate-config --root /mnt

# Copy the generated hardware-configuration.nix to appropriate host directory
cp /mnt/etc/nixos/hardware-configuration.nix hosts/laptopA/
```

### 2. Update Hardware Configuration Files
Edit the hardware-configuration.nix files in each host directory and replace the placeholder UUIDs with actual values from your system.

### 3. SSH Keys Setup
Add your SSH public keys to the user configuration:

```nix
# In hosts/*/configuration.nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-key-here duck@homelab"
];
```

## Building and Deploying

### Local Build and Switch
```bash
# Build and switch to new configuration
sudo nixos-rebuild switch --flake .#laptopA

# For laptopB
sudo nixos-rebuild switch --flake .#laptopB
```

### Remote Deployment
```bash
# Deploy to remote machine
nixos-rebuild switch --flake .#laptopA --target-host duck@laptopA.homelab.local

# With sudo privileges
nixos-rebuild switch --flake .#laptopB --target-host duck@laptopB.homelab.local --use-remote-sudo
```

### Home Manager
```bash
# Switch Home Manager configuration
home-manager switch --flake .#duck@laptopA

# For laptopB
home-manager switch --flake .#duck@laptopB
```

## Development Shell

Enter a development environment with all homelab tools:

```bash
nix develop
# or
nix shell
```

This provides access to:
- Terraform
- Ansible  
- kubectl and Kubernetes tools
- Docker tools
- Monitoring clients
- Text processing tools (jq, yq)

## Customization

### Adding Packages
1. **System packages**: Add to `commonPackages` in `flake.nix` or to individual host configurations
2. **User packages**: Add to `home.packages` in respective `home.nix` files

### Environment Variables
Set in the host configuration:
```nix
environment.variables = {
  CUSTOM_VAR = "value";
};
```

### Services
Enable services in host configurations:
```nix
services.myservice = {
  enable = true;
  # configuration options
};
```

## Maintenance

### Updates
```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake update nixpkgs

# Rebuild with updates
sudo nixos-rebuild switch --flake .#laptopA
```

### Cleanup
```bash
# Clean up old generations (run regularly)
sudo nix-collect-garbage -d

# Clean up boot entries
sudo /run/current-system/bin/switch-to-configuration boot
```

### Backup
```bash
# Backup current configuration
cp -r /etc/nixos ~/backups/nixos-$(date +%Y%m%d)

# Or use the built-in backup function (laptopB)
homelab-backup
```

## Security Considerations

### LaptopA (Development)
- Firewall configured with development ports
- Sudo without password for development convenience
- Docker access for user

### LaptopB (Server)
- Restrictive firewall configuration
- Fail2ban for SSH protection
- AppArmor enabled
- Sudo requires password
- SSH hardening enabled

## Troubleshooting

### Boot Issues
```bash
# Boot into previous generation
# Select older generation from bootloader menu

# Or rollback
sudo nixos-rebuild --rollback switch
```

### Configuration Issues
```bash
# Test configuration without switching
sudo nixos-rebuild test --flake .#laptopA

# Build without switching
sudo nixos-rebuild build --flake .#laptopA
```

### Debugging
```bash
# Check what will be built
nix build .#nixosConfigurations.laptopA.config.system.build.toplevel --dry-run

# Verbose output
sudo nixos-rebuild switch --flake .#laptopA --show-trace
```

## Useful Commands

```bash
# List installed packages
nix-env -q

# Search for packages
nix search nixpkgs firefox

# Check system configuration
nix show-config

# View flake info
nix flake show

# Check flake metadata
nix flake metadata
```

## Integration with Homelab

These configurations integrate with the broader homelab infrastructure:

- **Jenkins**: Build agents can be configured on both hosts
- **ArgoCD**: kubectl and cluster access configured
- **Monitoring**: Prometheus exporters and Grafana dashboards
- **Container Runtime**: Docker configured for CI/CD pipelines
- **Infrastructure**: Terraform and Ansible for infrastructure management

## Support

For issues specific to this NixOS configuration:
1. Check the NixOS manual: https://nixos.org/manual/
2. NixOS options search: https://search.nixos.org/
3. Home Manager options: https://mipmip.github.io/home-manager-option-search/
4. Homelab documentation in `docs/` directory