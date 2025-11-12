# NixOS configuration for laptop-firebat
{ config, pkgs, k8sRole, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/certs/ca.nix
    ../../modules/boot/boot-uefi.nix
    ../../modules/roles/tailscale-client.nix
    ../../environments/production.nix
    (if k8sRole == "control-plane"
     then ../../modules/roles/control-plane.nix
     else ../../modules/roles/worker-node.nix)
  ];

  # Hostname
  networking.hostName = "ducksnest-laptop-firebat";

  # Development-focused kernel parameters
  boot.kernelParams = [
    "quiet"
    "splash"
    "mitigations=off"  # Better performance for development
  ];



  # Development-focused shell aliases
  environment.shellAliases = {
    k = "kubectl";
    kx = "kubectl explain";
    kgp = "kubectl get pods";
    kgs = "kubectl get services";
    htop = "btop";
    ports = "ss -tulpn";
    homelab-rebuild = "sudo nixos-rebuild switch --flake .#laptop-firebat";
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
