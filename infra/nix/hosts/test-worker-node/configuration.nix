{ config, pkgs, lib, k8sRole ? "worker", ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/certs/ca.nix
    ../../modules/roles/worker-node.nix
  ];

  networking.hostName = "test-worker-node";
  networking.hostId = "87654321";
  networking.interfaces.eth0.useDHCP = true;

  system.stateVersion = "25.05";
}
