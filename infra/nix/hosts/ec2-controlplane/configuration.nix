{ config, pkgs, ... }:

{
  imports = [
    ../../modules/boot/ec2-modules.nix 
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/roles/control-plane.nix
    ../../modules/roles/tailscale-client.nix
  ];

  # Hostname
  networking.hostName = "ducksnest-controlplane";

  # AWS EC2 specific configuration
  ec2.hvm = true;

  # Additional packages (base packages in control-plane.nix)

  # Control plane specific environment variables (KUBECONFIG in control-plane.nix)
  environment.variables = {
    HOMELAB_ROLE = "control-plane";
    HOMELAB_ENV = "production";
  };

  # Control plane specific services
  services = {
    # Override Grafana settings for control plane
    grafana.settings.server.domain = "grafana.homelab.ducksnest.com";

    # Time synchronization
    timesyncd = {
      enable = true;
      servers = [ "time.google.com" "time.cloudflare.com" ];
    };
  };

  # Kubeadm services now handled by control-plane.nix module

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}