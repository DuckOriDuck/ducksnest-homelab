# ducksnest-homelab
- [Introduction](#introduction)
- [Purpose](#purpose)
- [Tech Stacks](#tech-stacks)
  - [Hardware](#hardware)
    - [On Premises](#on-premises)
    - [Cloud](#cloud)
  - [Software](#software)
- [Network Design](#network-design)
  - [Topology Summary (Assuming EC2 as Control Plane)](#topology-summary-assuming-ec2-as-control-plane)
  - [Network & CIDR Map](#network--cidr-map)
- [Current Progress](#current-progress)
  - [Kubernetes the Nix Way](#kubernetes-the-nix-way)
  - [WN Auto Join](#wn-auto-join)

## Introduction
This is My hybrid cloud homelab: NixOS on-prem worker node, EC2 control plane.
I aim to manage everything as declaratively as possible, taking advantage of NixOS’s design for reproducible infrastructure.
I plan to deploy my personal blog and service portfolios on this cluster.

## Purpose
1. To make the best use of surplus computing resources at home
2. To study and gain deeper practical experience with Nix and Kuberentes
3. To have fun -*Homo Ludens*: humans are playful by nature. Through this project, I want to make learning and building systems more enjoyable and creative.

### Master Goal

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
| **OS** | NixOS | My "ultra" PC only supports systemd-boot, so I had to choose an OS that comes with it by default — **Arch Linux**, **NixOS**, or **FreeBSD**. I chose NixOS because it’s compatible with most modern software dependencies and more stable than Arch Linux.  |
| **Container Orchestration** | Kubernetes | I chose Kubernetes because it felt like the most balanced option. It lets me manage nodes and containers automatically in one place, and with tools like Helm or Argo, even the internal workflows can stay declarative. |
| **VPN** | Tailscale |I chose **Tailscale** because it’s simple and stable. I liked that I can later build my own VPN server with Headscale, and it’ll still work with the same Tailscale clients. It also connects to the network with just one command in my CI/CD pipeline, and managing network policies from the SaaS dashboard is super intuitive. |
| **CNI** | Calico | To support the hybrid networking model of Local + Tailscale VPN, I needed a CNI that could handle flexible routing and policy management without adding too much overhead. especially since this is my first time managing a Kubernetes cluster, so I went with **Calico**. -> **Flannel** was one of the options, but it’s more limited in terms of routing control and network policy features, which are essential for hybrid setups like this. -> **Cilium** was an option. it’s powerful and offers great eBPF-based observability, but it felt a bit overkill for my case, I might give it a try later once I’m more confident, it’s definitely an appealing technology. |
| **IaC** | NixOS Modules + Terraform | I use NixOS modules to manage Linux package dependencies because, NixOS. And I thought it was a good time to learn Terraform for provisioning cloud resources. AWS-native IaC tools felt too vendor-locked for my taste(I know Terraform is still tied to AWS in this case, but it’s a more open and flexible option overall.)|
| **CI/CD** | GitHub Actions | It was the most simple and intuitive |


### Network Design
<img width="763" height="721" alt="제목 없는 다이어그램-페이지-2 drawio" src="https://github.com/user-attachments/assets/e0c73acf-7678-49ad-bc1a-286b41fc0f09" />

#### Topology Summary (Assuming EC2 as Control Plane)
- **Control Plane**: `EC2`
- **Workers:** `laptop-firebat`, `laptop-ultra`, `laptop-old`
- **Routing Strategy:**
  - Workers located in the same physical site communicate through **Local Network** routes.
  - `EC2` ↔ `On-prem workers` communicate through **Tailscale**.
  - Upper-layer routing (L3 path selection) is handled by the host OS routing table, while **Calico VXLAN** operates on top of it.
 
#### Network & CIDR Map
| Item | CIDR / Interface | Notes |
| --- | --- | --- |
| **Pod CIDR (Calico pool)** | 10.244.0.0/16 | Uses Calico VXLAN |
| **Service CIDR**           | 10.96.0.0/12 | ClusterIP and other virtual service IPs |
| **Local LAN**              | 192.168.0.0/24 | Default route for nodes within the same local network |
| **Tailnet (Tailscale)**    | 100.64.0.0/10 | Used as L3 route for API access between EC2 and on-prem nodes |
| **Node IP Autodetection**  | interface=wlan* | Excludes tailscale0 and uses the Wi-Fi interface (wlan0) as the node’s primary IP for Calico VXLAN encapsulation and routing. |
| **Calico MTU**             | 1280 | Aligned with Tailnet MTU to prevent fragmentation after encapsulation in tailnet|

## Current Progress
### Kubernetes the Nix Way

### WN Auto Join

### Test Environment Configuration With QEMU
