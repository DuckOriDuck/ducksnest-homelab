# NixOS configuration for laptop-old - Worker node
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/boot/boot-bios.nix
    ../../modules/roles/worker-node.nix
    ../../modules/roles/tailscale-client.nix
  ];

  # GRUB device configuration for BIOS boot
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # Hostname
  networking.hostName = "ducksnest-laptop-old";

  # Worker node specific kernel parameters
  boot.kernelParams = [
    "quiet"
    "elevator=mq-deadline"
    "intel_pstate=active"
  ];

  # Services specific to worker node
  services = {
    # OpenSSH daemon
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    # Power management - no sleep
    logind.extraConfig = ''
      HandleLidSwitch=ignore
      HandleLidSwitchDocked=ignore
      HandleLidSwitchExternalPower=ignore
      IdleAction=ignore
    '';
  };

  # Environment variables for worker node
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    HOMELAB_ENV = "laptop-old";
    HOMELAB_ROLE = "worker-node";
  };

  # Worker node shell aliases
  environment.shellAliases = {
    # Kubernetes shortcuts
    k = "kubectl";
    
    # System monitoring
    htop = "btop";
    ports = "ss -tulpn";
    
    # Docker shortcuts
    d = "docker";
    dps = "docker ps";
  };

  # Extended locale settings
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