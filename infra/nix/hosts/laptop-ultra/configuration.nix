# NixOS configuration for laptop-ultra - Worker node  
{ config, pkgs, commonPackages, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/worker-node.nix
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
  environment.systemPackages = commonPackages ++ (with pkgs; [
    # Development IDEs
    vscode
    jetbrains.idea-community
    
    # GUI tools for development
    postman
    dbeaver
    wireshark
    lens  # Kubernetes IDE
    
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
  ]);

  # Services specific to development worker node
  services = {
    # K3s worker node
    k3s = {
      enable = true;
      role = "agent";
      serverAddr = "https://ducksnest-controlplane:6443";
      # tokenFile = "/var/lib/k3s/token";  # Set this with the cluster token
    };

    # Desktop environment for development
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      layout = "us";
      xkbVariant = "";
    };
    
    # Audio for development environment
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    
    # Virtualization
    libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
    };
    
    # Development databases
    postgresql = {
      enable = true;
      ensureDatabases = [ "homelab_dev" ];
      ensureUsers = [
        {
          name = "duck";
          ensurePermissions = {
            "DATABASE homelab_dev" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    
    redis.servers."dev" = {
      enable = true;
      port = 6379;
    };
  };

  # Audio configuration
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # Virtualization setup
  virtualisation = {
    libvirtd.enable = true;
  };

  # Development-friendly security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;  # Convenience for development
  };

  # Environment variables for development worker node
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    NODE_ENV = "development";
    HOMELAB_ENV = "laptop-ultra";
    HOMELAB_ROLE = "worker-node-dev";
  };

  # Development-focused shell aliases
  environment.shellAliases = {
    # Kubernetes shortcuts
    k = "kubectl";
    k3 = "k3s kubectl";
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
  system.stateVersion = "23.11";
}