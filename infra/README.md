## WARNING: THIS DOCUMENT IS ROUGH DRAFT WROTE WITH CLUADE CODE! I WILL BE MAKING MAJOUR CHANGES ASAP
This document is still under heavy revision, and major updates will be made soon.
Currently, the configurations are set with firebat-laptop as the control plane, and most parameters are tuned for the test environment.
This setup was intentional for debugging and validation purposes.

# Infrastructure
This directory contains all infrastructure-as-code for the DucksNest homelab, split into cloud provisioning (Terraform) and system configuration (Nix).

## Directory Structure

```plaintext
infra/
├── terraform/              # AWS cloud infrastructure provisioning
│   ├── main.tf            # EC2 instances, AMI, IAM
│   ├── networks.tf        # VPC, subnets, security groups
│   ├── variable.tf        # Input variables
│   └── user-data/         # Cloud-init scripts
├── nix/                   # NixOS system configurations
│   └── (see [nix/README.md](nix/README.md) for details)
└── k8nix-cert-management/ # Vendored K8Nix certificate toolkit
```

## Terraform (Cloud Infrastructure)

**Purpose**: Provisions AWS infrastructure for the Kubernetes control plane.

**What it manages**:

- **EC2 Instance** (t3.medium)
  - Custom NixOS AMI (`NixOS-25.05-updated-kernel-image`)
  - 20GB encrypted gp3 root volume
  - Tailscale VPN setup via user-data
  - IAM instance profile for AWS API access

- **Networking**
  - VPC: `10.20.0.0/16`
  - Public subnets: `10.20.0.0/24` (ap-northeast-2a), `10.20.1.0/24` (ap-northeast-2c)
  - Internet Gateway for public access
  - Security group: Egress-only (ingress via Tailscale VPN)

- **State Management**
  - S3 backend: `s3://ducksnest-terraform-state/homelab/terraform.tfstate`
  - DynamoDB locking: `ducksnest-terraform-locks`
  - KMS encryption: `alias/ducksnest-terraform-state-key`

**Usage**:

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

**Outputs**: Control plane public/private IPs, VPC ID, subnet IDs

## Nix (System Configuration)

**Purpose**: Declaratively configures all NixOS systems (on-prem and cloud) as Kubernetes nodes.

**What it manages**:

- **Operating System**: Complete NixOS configuration for all nodes ([common modules](nix/README.md#6-common-modules-modulescommon))
- **Kubernetes Components**: [Control plane](nix/README.md#control-plane-modulesrolescontrol-planenix) (etcd, apiserver, controller, scheduler) and [worker](nix/README.md#worker-node-modulesrolesworker-nodenix) (kubelet)
- **TLS Certificates**: [K8Nix-based certificate generation](nix/README.md#2-certificate-management-modulescertscanix) and distribution
- **CNI Networking**: Calico CNI with VXLAN backend
- **Bootstrap Automation**: [systemd services for cluster initialization](nix/README.md#3-kubernetes-bootstrap-module-moduleskubernetes-bootstrapnix)
- **Secrets**: [Age-encrypted certificates](nix/README.md#9-secrets-management-secrets) and credentials
- **Monitoring**: Optional [Prometheus + Grafana stack](nix/README.md#observability-modulesrolesobservabilitynix)

**How it works**:

1. [Flake](nix/README.md#1-flake-structure-flakenix) defines all hosts with their Kubernetes roles
2. Modules compose system configuration ([base](nix/README.md#6-common-modules-modulescommon), [security](nix/README.md#6-common-modules-modulescommon), [boot](nix/README.md#7-boot-modules-modulesboot), [roles](nix/README.md#4-role-modules))
3. `nixos-rebuild switch --flake .#<hostname>` deploys configuration
4. [Bootstrap tasks](nix/README.md#3-kubernetes-bootstrap-module-moduleskubernetes-bootstrapnix) automatically initialize the cluster at boot

**→ See [nix/README.md](nix/README.md) for comprehensive documentation**

## Division of Responsibility

| Concern | Managed By | Why |
|---------|-----------|-----|
| **Cloud Resources** | Terraform | Industry standard for multi-cloud provisioning |
| **Network Infrastructure** | Terraform | VPC, subnets, security groups are AWS-specific |
| **VM Provisioning** | Terraform | EC2 instance lifecycle management |
| **OS Configuration** | Nix | Declarative, reproducible system configuration |
| **Package Management** | Nix | Version-locked dependencies, atomic upgrades |
| **Kubernetes Setup** | Nix | Tight integration with system services and certificates |
| **Secrets** | Nix (agenix) | Age-encrypted, version-controlled, host-specific decryption |
| **Application Deployment** | Kubernetes | (Future: Helm/Argo for workloads) |

## Workflow

### Initial Setup

1. **Provision cloud infrastructure**:

   ```bash
   cd infra/terraform
   terraform apply
   ```

2. **Generate TLS certificates**:

   ```bash
   cd infra/nix
   nix run .#certs-recreate
   git add secrets/certs && git commit
   ```

3. **Deploy NixOS to EC2**:

   ```bash
   # SSH to EC2 instance
   ssh admin@<ec2-ip>

   # Clone repo and switch
   git clone <repo-url>
   cd ducksnest-homelab/infra/nix
   sudo nixos-rebuild switch --flake .#ec2-controlplane
   ```

4. **Deploy on-prem nodes**:

   ```bash
   # On each on-prem machine
   sudo nixos-rebuild switch --flake .#laptop-firebat
   sudo nixos-rebuild switch --flake .#laptop-ultra
   ```

### Updates

- **Terraform changes**: `terraform plan && terraform apply`
- **Nix changes**: `nixos-rebuild switch --flake .#<hostname>` on each node
- **Certificate rotation**: `nix run .#certs-recreate && git commit` then redeploy nodes

## K8Nix Certificate Management

The `k8nix-cert-management/` directory contains a vendored copy of the [K8Nix](https://gitlab.luxzeitlos.de/k8nix) certificate toolkit. This provides the `certToolkit` NixOS module used for declarative TLS certificate generation.

**Why vendored**: Ensures reproducibility and allows local patches if needed.

**What it provides**:

- NixOS module for declarative certificate definitions
- Integration with agenix for secret encryption
- CLI tool for certificate generation (`nix run .#certs-recreate`)

See [nix/docs/certtoolkit-k8s.md](nix/docs/certtoolkit-k8s.md) for usage details.
