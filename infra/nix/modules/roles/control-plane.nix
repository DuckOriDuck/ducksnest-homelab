{ config, pkgs, ... }:

{
  # Control plane configuration for Kubernetes cluster

  virtualisation = {
    cri-o = {
      enable = true;
    };
  };

  # System packages for control plane
  environment.systemPackages = with pkgs; [
    # Kubernetes tools
    kubernetes
    kubernetes-helm
    kustomize
    k9s
    
    # Container tools
    cri-o
    cri-tools

    # Network tools
    # Calico uses kubectl apply, no special CLI needed

    # System utilities required by kubeadm
    util-linux
    coreutils
    iproute2
    iptables
    ethtool
    socat
    
    # AWS CLI and tools
    awscli2
    jq

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

  # Services for control plane
  # Note: kubelet is managed by kubeadm, not NixOS kubernetes module
  services = {};

  # Custum Kubeadm initialization service
  systemd.services.kubeadm-init = {
    enable = true;
    description = "Initialize Kubernetes control plane with kubeadm";
    after = [ "network.target" "cri-o.service" ];
    wants = [ "cri-o.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        initScript = pkgs.writeScript "kubeadm-init.sh" ''
          #!/bin/bash
          set -e
          
          # Check if cluster is already initialized
          if [ -f /etc/kubernetes/admin.conf ]; then
            echo "Cluster already initialized"
            exit 0
          fi
          
          # Initialize cluster with non-overlapping CIDR
          ${pkgs.kubernetes}/bin/kubeadm init \
            --pod-network-cidr=10.244.0.0/16 \
            --service-cidr=10.96.0.0/12 \
            --cri-socket=unix:///var/run/crio/crio.sock
          
          # Set up kubectl for root user
          mkdir -p /root/.kube
          cp /etc/kubernetes/admin.conf /root/.kube/config
          chown root:root /root/.kube/config
          
          echo "Control plane initialized successfully"
        '';
      in "${initScript}";
      
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Install Calico CNI
  systemd.services.calico-install = {
    enable = true;
    description = "Install Calico CNI network plugin";
    after = [ "kubeadm-init.service" ];
    wants = [ "kubeadm-init.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        calicoScript = pkgs.writeScript "calico-install.sh" ''
          #!/bin/bash
          set -e
          
          # Check if Calico is already installed
          if ${pkgs.kubernetes}/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf get daemonset -n kube-system calico-node >/dev/null 2>&1; then
            echo "Calico already installed"
            exit 0
          fi
          
          # Install Calico with host networking (perfect for Tailscale)
          ${pkgs.kubernetes}/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
          
          echo "Calico installed successfully"
        '';
      in "${calicoScript}";
      
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Generate join command for workers (Option A: file-based)
  systemd.services.kubeadm-gen-join = {
    enable = true;
    description = "Generate kubeadm join command";
    after = [ "kubeadm-init.service" ];
    wants = [ "kubeadm-init.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = let
        genJoinScript = pkgs.writeScript "kubeadm-gen-join.sh" ''
          #!/bin/bash
          set -e
          
          if [ ! -f /etc/kubernetes/admin.conf ]; then
            echo "Cluster not initialized yet"
            exit 1
          fi
          
          # Create shared directory and make accessible
          mkdir -p /tmp/k8s-shared
          
          # Generate join command and save to shared location
          ${pkgs.kubernetes}/bin/kubeadm token create --print-join-command > /tmp/k8s-shared/join-command.txt
          chmod 644 /tmp/k8s-shared/join-command.txt
          
          # Also create a simple HTTP server for easy access (Optional)
          ${pkgs.python3}/bin/python3 -m http.server 8888 -d /tmp/k8s-shared &
          
          echo "Join command saved to /tmp/k8s-shared/join-command.txt"
          echo "Also available via HTTP at :8888/join-command.txt"
        '';
      in "${genJoinScript}";
    };
  };

  # Periodic join command refresh (for security)
  systemd.services.kubeadm-refresh-join = {
    enable = true;
    description = "Refresh kubeadm join command";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/systemctl start kubeadm-gen-join.service";
    };
  };
  
  systemd.timers.kubeadm-refresh-join = {
    enable = true;
    description = "Refresh kubeadm join command every 23 hours";
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  # System tuning for Kubernetes (bridge settings handled by kubelet module)
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  # Load required kernel modules (br_netfilter handled by kubelet module)
  boot.kernelModules = [ "overlay" ];

  # Environment variables for Kubernetes
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
  };
}