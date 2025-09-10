{ config, pkgs, ... }:

{
  # Worker node configuration for Kubernetes cluster
  
  # Enable container runtime
  virtualisation = {
    cri-o = {
      enable = true;
    };
  };

  # Tailscale handles networking, no firewall needed

  # System packages for worker nodes
  environment.systemPackages = with pkgs; [
    # Kubernetes tools
    kubernetes  # includes kubectl and kubeadm
    k9s
    
    # Container tools
    cri-o
    cri-tools

    # Network tools (Calico uses kubectl, no special CLI needed)

    # System utilities required by kubeadm
    util-linux
    coreutils
    iproute2
    iptables
    ethtool
    socat
    
    # System utilities
    git
    curl
    wget
    unzip
    htop
    tree
    vim
    
    # extra
    fastfetchMinimal
  ];

  # Services for worker nodes
  services = {
    # Enable kubelet service for kubeadm
    kubernetes.kubelet = {
      enable = true;
      address = "0.0.0.0";
      port = 10250;
    };
  };

  # Kubeadm join service (Option A: file-based)
  systemd.services.kubeadm-join = {
    enable = true;
    description = "Join Kubernetes cluster as worker node";
    after = [ "network.target" "cri-o.service" ];
    wants = [ "cri-o.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        joinScript = pkgs.writeScript "kubeadm-join.sh" ''
          #!/bin/bash
          set -e
          
          # Check if node is already joined
          if [ -f /etc/kubernetes/kubelet.conf ]; then
            echo "Node already joined to cluster"
            exit 0
          fi
          
          # Wait for join command file (Option A)
          echo "Waiting for join command from control plane..."
          while [ ! -f /tmp/k8s-shared/join-command.txt ]; do
            echo "Join command not found, waiting..."
            sleep 10
          done
          
          # Read and execute join command
          JOIN_CMD=$(cat /tmp/k8s-shared/join-command.txt)
          echo "Executing: $JOIN_CMD --cri-socket=unix:///var/run/crio/crio.sock"
          
          # Execute join with CRI-O socket
          $JOIN_CMD --cri-socket=unix:///var/run/crio/crio.sock
          
          echo "Successfully joined cluster"
        '';
      in "${joinScript}";
      
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "300"; # 5 minutes timeout
    };
  };

  # System tuning for Kubernetes
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  # Load required kernel modules
  boot.kernelModules = [ "br_netfilter" "overlay" ];
}