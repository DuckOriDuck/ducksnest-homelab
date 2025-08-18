{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/common/boot-uefi.nix
    ../../modules/roles/control-plane.nix
    ../../modules/roles/tailscale-client.nix
  ];

  # Hostname
  networking.hostName = "ducksnest-controlplane";

  # AWS EC2 specific configuration
  ec2.hvm = true;

  # System packages specific to control plane
  environment.systemPackages = with pkgs; [
    # Additional control plane tools
    kubernetes-helm
    
    # AWS CLI
    awscli2
  ];

  # Control plane specific environment variables
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    HOMELAB_ROLE = "control-plane";
    HOMELAB_ENV = "production";
  };

  # Control plane specific services
  services = {
    # Override Grafana settings for control plane
    grafana.settings.server.domain = "grafana.homelab.ducksnest.com";
    
    # K3s control plane
    k3s = {
      enable = true;
      role = "server";
      extraFlags = [
        "--disable=traefik"  # We'll use nginx ingress
        "--disable=servicelb"
        "--write-kubeconfig-mode=644"
        "--cluster-init"
        "--disable-cloud-controller"
      ];
    };

    # Time synchronization
    timesyncd = {
      enable = true;
      servers = [ "time.google.com" "time.cloudflare.com" ];
    };
  };

  # Systemd services for cluster initialization
  systemd.services = {
    # Cluster initialization with kubeadm
    kubeadm-init = {
      description = "Initialize Kubernetes cluster with kubeadm";
      after = [ "network-online.target" "cri-o.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "kubeadm-init" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          
          # Check if cluster is already initialized
          if [ -f /etc/kubernetes/admin.conf ]; then
            echo "Kubernetes cluster already initialized"
            exit 0
          fi
          
          # Initialize cluster with kubeadm
          ${pkgs.kubernetes}/bin/kubeadm init \
            --pod-network-cidr=10.244.0.0/16 \
            --service-cidr=10.96.0.0/12 \
            --cri-socket=unix:///var/run/crio/crio.sock
          
          # Set up kubeconfig for root
          mkdir -p /root/.kube
          cp /etc/kubernetes/admin.conf /root/.kube/config
          
          # Install Flannel CNI
          ${pkgs.kubectl}/bin/kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
        '';
      };
    };
  };

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}