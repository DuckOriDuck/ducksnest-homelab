{ config, pkgs, k8sRole, ... }:

{
  imports = [
    ../../modules/boot/ec2-modules.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/certs/ca.nix
    ../../modules/roles/tailscale-client.nix
    ../../environments/production.nix
    (if k8sRole == "control-plane"
     then ../../modules/roles/control-plane.nix
     else ../../modules/roles/worker-node.nix)
  ];

  # Hostname
  networking.hostName = "ducksnest-controlplane";

  # AWS EC2 specific configuration
  ec2.hvm = true;

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