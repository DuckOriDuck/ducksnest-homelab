# NixOS configuration for laptop-old
{ config, pkgs, lib, k8sRole, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/common/observability.nix
    ../../modules/common/tailscale-client.nix
    ../../modules/boot/boot-bios.nix
    ../../environments/production.nix
    (if k8sRole == "control-plane"
     then ../../modules/roles/control-plane.nix
     else ../../modules/roles/worker-node.nix)
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

  # Disable swap for Kubernetes (override hardware-configuration.nix)
  swapDevices = lib.mkForce [ ];

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
    logind.settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        IdleAction = "ignore";
      };
    };
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