{ config, pkgs, lib, k8sRole ? "control-plane", ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/certs/ca.nix
    ../../modules/roles/control-plane.nix
  ];

  networking.hostName = "test-controlplane";
  networking.hostId = "12345678";
  networking.interfaces.eth0.useDHCP = true;

  system.stateVersion = "25.05";
}
