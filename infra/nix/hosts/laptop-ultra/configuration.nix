# NixOS configuration for laptop-ultra
{ config, pkgs, k8sRole, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/common/observability.nix
    ../../modules/common/tailscale-client.nix
    ../../modules/boot/boot-uefi.nix
    ../../environments/production.nix
    (if k8sRole == "control-plane"
     then ../../modules/roles/control-plane.nix
     else ../../modules/roles/worker-node.nix)
  ];

  # Hostname
  networking.hostName = "ducksnest-laptop-ultra";

  # Development-focused kernel parameters
  boot.kernelParams = [
    "quiet"
    "splash" 
    "mitigations=off"  # Better performance for development
  ];

  # Additional development packages for worker node
  environment.systemPackages = with pkgs; [

    # Additional development tools
    podman
    buildah
    skopeo
    
    # Virtualization for testing
    qemu
    libvirt
    virt-manager
    
    # Network debugging
    tcpdump
    iftop
    nethogs
    
    # Text editors
    neovim
    emacs
    
    # File management
    mc
    ranger
  ];

  # Services specific to development worker node
  services = {
    # OpenSSH daemon
    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    # Power management - no sleep
    logind.settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        IdleAction = "ignore";
      };
    };
  };

  # Virtualization setup
  virtualisation = {
    libvirtd.enable = true;
  };

  # Development-friendly security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Environment variables for development worker node
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    NODE_ENV = "development";
    HOMELAB_ENV = "laptop-ultra";
    HOMELAB_ROLE = "worker-node-dev";
  };

  # Development-focused shell aliases
  environment.shellAliases = {
    # Kubernetes shortcuts
    k = "kubectl";
    kx = "kubectl explain";
    kgp = "kubectl get pods";
    kgs = "kubectl get services";
    
    # Docker shortcuts
    d = "docker";
    dc = "docker-compose";
    
    # Infrastructure shortcuts
    tf = "terraform";
    ans = "ansible";
    
    # Git shortcuts
    g = "git";
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    
    # System monitoring
    htop = "btop";
    ports = "ss -tulpn";
    
    # Homelab management
    homelab-rebuild = "sudo nixos-rebuild switch --flake .#laptop-ultra";
  };

  # Extended locale settings for development
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.UTF-8";
    LC_IDENTIFICATION = "ko_KR.UTF-8";
    LC_MEASUREMENT = "ko_KR.UTF-8";
    LC_MONETARY = "ko_KR.UTF-8";
    LC_NAME = "ko_KR.UTF-8";
    LC_NUMERIC = "ko_KR.UTF-8";
    LC_PAPER = "ko_KR.UTF-8";
    LC_TELEPHONE = "ko_KR.UTF-8";
    LC_TIME = "ko_KR.UTF-8";
  };

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}