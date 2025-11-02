# ducksnest-homelab


## Introduction
This is My hybrid cloud homelab: NixOS on-prem worker node, EC2 control plane.
I aim to manage everything as declaratively as possible, taking advantage of NixOS’s design for reproducible infrastructure.
I plan to deploy my personal blog and service portfolios on this cluster.

## Purpose
1. To make the best use of surplus computing resources at home
2. To study and gain deeper practical experience with Nix and Kuberentes
3. To have fun -*Homo Ludens*: humans are playful by nature. Through this project, I want to make learning and building systems more enjoyable and creative.

## Tech Stacks

### Compute Resources

#### On Premises
| Alias | CPU | Memory | Disk | GPU |
|-------|------|---------|------|------|
| **firebat** | Intel N100 (4) @ 3.40 GHz | 15.4 GiB | 467.4 GiB ext4 | Intel UHD Graphics |
| **ultra** | Intel i5-8250U (8) @ 3.40 GHz | 15.5 GiB | 914.8 GiB ext4 | NVIDIA GTX 1050 Mobile / Intel UHD 620 |
| **old** | Intel i3-M 330 (4) @ 2.13 GHz | 1.9 GiB | 288.6 GiB ext4 | NVIDIA GeForce 310M |

#### Cloud
| Alias | Instance Type | vCPU | Memory |
|--------|----------------|------|----------|
| **control-plane (EC2)** | t3.medium | 2 | 4 GiB |

### Technology Stack

| Category | Technology | Why This Choice |
|----------|------------|-----------------|
| **OS** | NixOS | Declarative configuration enables reproducible infrastructure and atomic rollbacks |
| **Container Orchestration** | Kubernetes | Industry-standard orchestration for managing containerized workloads across hybrid cloud |
| **Networking** | Tailscale + Calico CNI | Tailscale provides secure VPN overlay (WireGuard) without port forwarding; Calico enables efficient pod networking with BGP |
| **IaC** | NixOS Modules + Terraform | NixOS manages system configs; Terraform provisions AWS resources |
| **CI/CD** | GitHub Actions | Automated infrastructure validation and binary cache generation |
| **Security** | Custom CA + Tailscale ACLs | Self-managed certificates for cluster components; centralized network access control |
| **Test Environment** | NixOS VMs | Local testing before deploying to production infrastructure |

**Network Design:**

- Pod Network: `10.244.0.0/16` (Calico CNI)
- Service Network: `10.96.0.0/12` (Kubernetes services)
- Node Network: `100.64.0.0/10` (Tailscale overlay)
- On-premises LAN: `192.168.0.0/24`

## Current Progress
