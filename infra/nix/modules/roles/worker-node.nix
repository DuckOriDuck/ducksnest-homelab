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
  # Note: kubelet is managed by kubeadm, not NixOS kubernetes module
  services = {};

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
          
          # Try to get join command via HTTP first, fallback to file
          echo "Getting join command from control plane..."
          
          # Option A: Try HTTP first (requires CP to be accessible)
          if ${pkgs.curl}/bin/curl -f -s http://control-plane-ip:8888/join-command.txt > /tmp/join-command.txt 2>/dev/null; then
            JOIN_CMD=$(cat /tmp/join-command.txt)
            echo "Got join command via HTTP"
          # Option B: Fallback to shared file location
          elif [ -f /tmp/k8s-shared/join-command.txt ]; then
            JOIN_CMD=$(cat /tmp/k8s-shared/join-command.txt)
            echo "Got join command via shared file"
          else
            echo "Waiting for join command file..."
            while [ ! -f /tmp/k8s-shared/join-command.txt ]; do
              echo "Join command not found, waiting..."
              sleep 10
            done
            JOIN_CMD=$(cat /tmp/k8s-shared/join-command.txt)
          fi
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

  # System tuning for Kubernetes (bridge settings handled by kubelet module)
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  # Load required kernel modules (br_netfilter handled by kubelet module)
  boot.kernelModules = [ "overlay" ];
}