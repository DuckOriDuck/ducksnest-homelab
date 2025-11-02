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

### Hardware

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

### Software

| Category | Technology | Reason For This Choice |
|----------|------------|-----------------|
| **OS** | NixOS | My "ultra" PC only supports systemd-boot, so I had to choose an OS that comes with it by default — Arch Linux, NixOS, or FreeBSD. I chose NixOS because it’s compatible with most modern software dependencies and more stable than Arch Linux.  |
| **Container Orchestration** | Kubernetes | I chose Kubernetes because it felt like the most balanced option. It lets me manage nodes and containers automatically in one place, and with tools like Helm or Argo, even the internal workflows can stay declarative. |
| **Networking** | Tailscale + Calico CNI |I chose Tailscale because it’s simple and stable. I liked that I can later build my own VPN server with Headscale, and it’ll still work with the same Tailscale clients. It also connects to the network with just one command in my CI/CD pipeline, and managing network policies from the SaaS dashboard is super intuitive. |
| **IaC** | NixOS Modules + Terraform | I use NixOS modules to manage Linux package dependencies because, NixOS. And I thought it was a good time to learn Terraform for provisioning cloud resources. AWS-native IaC tools felt too vendor-locked for my taste(I know Terraform is still tied to AWS in this case, but it’s a more open and flexible option overall.)|
| **CI/CD** | GitHub Actions | It was the most simple and intuitive |


**Network Design:**
TODO:

## Current Progress
TODO: