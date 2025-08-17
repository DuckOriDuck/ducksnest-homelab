# NixOS configuration for laptop-old - Worker node
{ config, pkgs, commonPackages, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/worker-node.nix
  ];

  # Hostname
  networking.hostName = "ducksnest-laptop-old";

  # Worker node specific kernel parameters
  boot.kernelParams = [
    "quiet"
    "elevator=mq-deadline"
    "intel_pstate=active"
  ];

  # Worker node specific packages
  environment.systemPackages = commonPackages ++ (with pkgs; [
    # GUI tools for worker node
    lens  # Kubernetes IDE
    remmina
    tigervnc
    
    # K3s agent
    k3s
  ]);

  # Services specific to worker node
  services = {
    # K3s worker node
    k3s = {
      enable = true;
      role = "agent";
      serverAddr = "https://ducksnest-controlplane:6443";
      # tokenFile = "/var/lib/k3s/token";  # Set this with the cluster token
    };

    # Desktop environment for worker node
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };
  };

  # Environment variables for worker node
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    HOMELAB_ENV = "laptop-old";
    HOMELAB_ROLE = "worker-node";
  };

  # Worker node shell aliases
  environment.shellAliases = {
    # Kubernetes shortcuts
    k = "kubectl";
    k3 = "k3s kubectl";
    
    # System monitoring
    htop = "btop";
    ports = "ss -tulpn";
    
    # Docker shortcuts
    d = "docker";
    dps = "docker ps";
  };

  # This value determines the NixOS release
  system.stateVersion = "23.11";
}