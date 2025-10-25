# Test VMs for DucksNest Kubernetes Cluster

This directory contains helper scripts and configurations for testing your NixOS Kubernetes cluster locally using QEMU VMs.

## Quick Start

### Build both test VMs (Control Plane + Worker Node)

```bash
cd infra/nix
./build-test-vms.sh
```

This will:
1. Build test-controlplane QEMU image
2. Build test-worker-node QEMU image
3. Create symlinks: `result-cp/` and `result-wn/`

**Time:** ~10-15 minutes (depending on your system)

### Run the VMs

**Control Plane:**
```bash
./result-cp/bin/run-ducksnest-test-controlplane-vm
```

**Worker Node:**
```bash
./result-wn/bin/run-ducksnest-test-worker-node-vm
```

Each VM will boot in a separate terminal window.

---

## Script Options

```bash
./build-test-vms.sh [OPTIONS]

Options:
  --cp-only     Build only control-plane VM
  --wn-only     Build only worker-node VM
  --run         Launch VMs in tmux after building (requires tmux)
  --help        Show help message
```

### Examples

**Build only control-plane:**
```bash
./build-test-vms.sh --cp-only
```

**Build both and run in tmux:**
```bash
./build-test-vms.sh --run
```

**Build only worker-node:**
```bash
./build-test-vms.sh --wn-only
```

---

## Testing Inside the VMs

### Control Plane

Once the control-plane VM boots, test it:

```bash
# Login as root (no password)

# Check Kubernetes API server
sudo systemctl status kube-apiserver

# Check bootstrap-rbac service
sudo systemctl status bootstrap-rbac
sudo journalctl -u bootstrap-rbac -n 50

# Check RBAC rules were applied
kubectl get clusterroles | grep kube-apiserver

# View all cluster resources
kubectl get all -A
```

### Worker Node

Once the worker-node VM boots:

```bash
# Login as root (no password)

# Check kubelet
sudo systemctl status kubelet

# Check if node registered with cluster
# (You'll need to provide the control-plane IP)
kubectl get nodes

# Check kubelet logs
sudo journalctl -u kubelet -n 50
```

---

## Networking Between VMs

By default, NixOS VMs use user-mode networking (no root required). If you need VMs to communicate:

1. Run with `-enable-kvm` for better networking
2. Or use bridged networking (requires root)

For detailed QEMU networking options, see: `man qemu-system-x86_64`

---

## Cleanup

**Remove VM symlinks:**
```bash
rm -f result-cp result-wn
```

**Remove tmux session:**
```bash
tmux kill-session -t ducksnest-test
```

---

## VM Specifications

### test-controlplane
- **Role:** Kubernetes Control Plane (API Server, Scheduler, Controller Manager, etcd)
- **Hostname:** ducksnest-test-controlplane
- **Services:** kube-apiserver, etcd, kube-controller-manager, kube-scheduler, kubelet, bootstrap-rbac
- **Networking:** eth0 (DHCP)

### test-worker-node
- **Role:** Kubernetes Worker Node
- **Hostname:** ducksnest-test-worker-node
- **Services:** kubelet, containerd
- **Networking:** eth0 (DHCP)

---

## Troubleshooting

### VM fails to boot
- Check if your system has enough RAM (at least 4GB free)
- Check disk space (need ~10GB per VM)
- Try: `nix flake check` to validate configuration

### RBAC errors in bootstrap service
Check logs:
```bash
sudo journalctl -u bootstrap-rbac -f
sudo journalctl -u kube-apiserver -f
```

### Kubernetes components not running
```bash
sudo systemctl list-units --type service --state failed
sudo journalctl -n 100 | grep -i error
```

### Network connectivity issues
Try pinging from control-plane to worker:
```bash
# Inside control-plane VM
ping <worker-ip>

# Inside worker VM
ping <control-plane-ip>
```

---

## Making Changes

To test configuration changes:

1. Edit `infra/nix/modules/roles/control-plane.nix` or other files
2. Rebuild: `./build-test-vms.sh`
3. Run: `./result-cp/bin/run-ducksnest-test-controlplane-vm`

The VM is a complete snapshot - no need to `nixos-rebuild switch` inside.

---

## Next Steps

After validating with test VMs:

1. Commit your changes
2. Apply to real machines: `nixos-rebuild switch --use-remote-sudo -h <hostname>`
3. Monitor: `journalctl -f` on the real machines

---

## References

- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Kubernetes Documentation: https://kubernetes.io/docs/
- NixOS Kubernetes Module: https://search.nixos.org/options?query=services.kubernetes
