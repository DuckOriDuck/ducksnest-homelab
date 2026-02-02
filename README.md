# ducksnest-homelab


## Documentation
- **[한국어 문서](/README-KOREAN.md)** - 한국어 문서는 여기에서 보시면 됩니다
- **[Infrastructure Overview](infra/README.md)** - Terraform and NixOS infrastructure documentation
- **[NixOS Architecture](infra/nix/README.md)** - Detailed NixOS configuration and Kubernetes setup

---

- [Introduction](#introduction)
- [Purpose](#purpose)
  - [Master Goal](#master-goal)
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
  - [EC2 Provisioning Problem – Fixed](#ec2-provisioning-problem--fixed)
  - [Calico Installation Problem – Fixed](#calico-installation-problem--fixed)
  - [CA/TLS Management Problem – Fixed](#catls-management-problem--fixed)
- [Current Issues](#current-issues)

## Introduction
This is My hybrid cloud homelab: NixOS on-prem worker node, EC2 control plane.
I aim to manage everything as declaratively as possible, taking advantage of NixOS’s design for reproducible infrastructure.
I plan to deploy my personal blog and service portfolios on this cluster.

## Purpose
1. To make the best use of surplus computing resources at home
2. To study and gain deeper practical experience with Nix and Kuberentes
3. To have fun -*Homo Ludens*: humans are playful by nature. Through this project, I want to make learning and building systems more enjoyable and creative.

### Master Goal
My ultimate goal is to build a complete automated deployment pipeline, a highly-available database, and a DR (Disaster Recovery) environment where EC2 automatically provisions replacement worker nodes when local machines go down. I also want to maximize the advantages of this hybrid cluster by combining cloud and on-premises resources, such as storing logs and database snapshots in S3, to complete my own homelab.

With the Control Plane situated on EC2, there are many expansion opportunities to explore, and I'm excited about the future development process.

#### On High-Availability Control Plane
I chose Kubernetes because it allows me to manage multiple nodes consistently from a central location and has excellent compatibility with various automation add-ons. However, given that my environment is not large-scale and doesn't have many actual users, I determined that configuring a high-availability Control Plane at this stage would be excessive in terms of both cost and operational burden. Therefore, a single Control Plane is sufficient for now, and I'm not currently considering a high-availability setup.

However, if I have the resources in the future, I'm open to expanding both the Control Plane and Worker Nodes by adding on-premises equipment. For now, I'll proceed with a single Control Plane-based setup, but I'll design the architecture to be easily expandable at any time.

## Tech Stacks

### Hardware

#### On Premises
| Alias | CPU | Memory | Disk | GPU |
|-------|------|---------|------|------|
| **firebat** | Intel N100 (4) @ 3.40 GHz | 15.4 GiB | 467.4 GiB ext4 | Intel UHD Graphics |
| **ultra** | Intel i5-8250U (8) @ 3.40 GHz | 15.5 GiB | 914.8 GiB ext4 | NVIDIA GTX 1050 Mobile / Intel UHD 620 |
| **old** | Intel i3-M 330 (4) @ 2.13 GHz | 1.9 GiB | 288.6 GiB ext4 | NVIDIA GeForce 310M |

<img width="2731" height="2048" alt="image" src="https://github.com/user-attachments/assets/7644de3e-9704-4b8a-9f87-3e933e18fabd" />

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
| **IaC** | NixOS Modules + Terraform | I use NixOS modules to manage Linux package dependencies because, NixOS. And I thought it was a good time to learn Terraform for provisioning cloud resources. AWS-native IaC tools felt too vendor-locked for my taste(I know Terraform is still tied to AWS in this case, but it's a more open and flexible option overall.). → See [infra/README.md](infra/README.md) and [infra/nix/README.md](infra/nix/README.md)|
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
| **Calico MTU**             | 1230 | Aligned with Tailnet MTU to prevent fragmentation after encapsulation in tailnet|


## Current Progress

### Kubernetes the Nix Way

All Kubernetes components are configured declaratively using NixOS modules.

The following are automatically bootstrapped at boot time:
- TLS certificate key pairs and CA
- Systemd-based automatic application of RBAC/CRD/Calico

### EC2 Provisioning Problem – Fixed
- **Problem:**
  - Building NixOS from scratch on a low-cost EC2 instance took way too long - around **15–20 minutes** per build, mostly due to limited disk I/O and CPU performance.
- **Options considered:**
  - AMI Baking: Way too slow and complicated to automate for every new Nix deployment. Needed something simpler.
  - Cachix: Starter plan costs **€50/month**, which was far beyond my budget.
  - Temporary "super build machine": Possible, but again, too complex for what I needed.
  - **S3 Binary Caching:** Whenever a build succeeds (either locally or in GitHub Actions), push the Nix binary cache to **S3**, then use it as a **substitute source** on EC2.
    → Simple, cheap, and effective this is the method I went with.
- **Result:**
  - Reduced initial NixOS build time on low-cost EC2 instances by **over 93%**, bringing it down to **under 1 minute**.

---

### Calico Installation Problem – Fixed
- **Problem**
  - On NixOS, subdirectories under `/etc` and `/opt` are immutable areas automatically generated by Nix build results. Any attempts to write or modify files at runtime get overwritten or rejected, preventing them from functioning properly.
  - This caused conflicts when Calico's official installation methods (Tigera Operator or Helm chart) tried to deploy CNI binaries to these directories, preventing proper installation.

- **Solution**
  - **Distributing Calico CNI Binaries via NixPkgs**
    - To work around NixOS's immutable filesystem constraints, Calico CNI binaries are installed on each node through NixPkgs during nixos-rebuild.
    - Binaries installed as Nix packages are `/nix/store`-based, so they don't face `/etc` or `/opt` write rejection issues.
    - Calico requires two binaries: `calico` and `calico-ipam`, but only `calico` exists in NixPkgs distribution.
    During installation, I created a symbolic link from `calico-ipam` → `calico` to meet the requirements.

  - **Declarative Bootstrapping of Calico Cluster Components**
    - Referencing [Calico the Hard Way](https://docs.tigera.io/calico/latest/getting-started/kubernetes/hardway/overview), I declared the YAML files for Calico components (CRDs, RBAC, Calico Node DaemonSet, etc.) and implemented a Nix module that bootstraps these on the Control Plane during nixos-rebuild.
    - I customized necessary parts such as binary locations, CNI config paths, and TLS certificates signed by the cluster-wide CA
    to align with the cluster structure.

- **Result**
  - Implemented a fully declarative installation structure where Calico components are automatically deployed during the NixOS bootstrapping phase, without Helm charts or Tigera Operator.
  - Using the `vxlan: CrossSubnet` option, on-premises nodes communicate via local network while connections to the Control Plane go through the Tailscale network.

---

### CA/TLS Management Problem – Fixed
- **Problem**
  - Without tools like Kubeadm, Minikube, or K3s, I was **deploying all Kubernetes components directly via Nix files**, requiring manual CA/TLS certificate management.
  - This created the burden of manually managing **dozens of TLS certificates and configuration files** for API Server, Kubelet, Kube-Controller-Manager, Scheduler, Etcd, etc.

- **Solution**
  - Built a custom automation pipeline Nix module, referencing the TLS management approach introduced in [NixCon 2025 - Kubernetes on Nix](https://www.youtube.com/watch?v=leR6m2plirs&t=967s) and [gitlab: Lukas - K8Nix](https://gitlab.com/luxzeitlos/k8nix).
  <img width="1307" height="511" alt="certtoolkit2" src="https://github.com/user-attachments/assets/1b04b42e-0698-4515-951a-4621b9560c63" />

  - Generate an **SSH key pair (asymmetric keys)** for each node:
    - **Public key** → Stored in GitHub repository
    - **Private key** → Stored in local NixOS filesystem on each node
  - When running `nix run certs-recreate`:
    1. Generate a new Cluster CA
    2. Generate **TLS certificates for all Kubernetes components** (API Server, Kubelet, ControllerManager, Scheduler, Etcd, etc.)
    3. **Encrypt each certificate's private key with the corresponding node's SSH public key**
    4. Upload the encrypted TLS private keys securely to the GitHub repository

  - When running `nixos-rebuild` on each node:
    1. Fetch encrypted TLS files from GitHub
    2. Decrypt using its own SSH private key
    3. Apply decrypted TLS certificates to each component (API server, kubelet, etc.)
    4. Services are automatically reconfigured according to declarative settings

- **Result**
  - Simplified the cumbersome CA/TLS management mechanism to a single `nix run certs-recreate` command.
  - Worker Nodes already have kubelet TLS certificates signed by the Control Plane's CA and API Server endpoint information, so they can automatically connect to the Control Plane simply by running nixos-rebuild, without any separate join process.

For more details: **[infra/nix/README.md](infra/nix/README.md)**

---

## Current Issues
- Revising and translating the AI-written rough draft **[infra/nix/README.md](infra/nix/README.md)**, **[infra/README.md](infra/README.md)** to Korean
- Adding ArgoCD for automated application deployment pipeline
- Adding observability, establishing log collection and management strategy
- High-availability PostgreSQL DB in the cluster using StatefulSets
- Deploying portfolio web application
- Activating endpoints using CloudFlare or Tailscale features for cluster deployment
