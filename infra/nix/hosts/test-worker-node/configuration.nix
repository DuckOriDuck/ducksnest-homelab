{ config, pkgs, lib, k8sRole ? "worker", ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/certs/ca.nix
    ../../modules/roles/worker-node.nix
  ];

  networking.hostName = "ducksnest-test-worker-node";
  networking.hostId = "87654321";
  networking.interfaces.eth0.useDHCP = true;

  # Override master address for test environment
  services.kubernetes.masterAddress = "ducksnest-test-controlplane";
  services.kubernetes.kubelet.kubeconfig.server = lib.mkForce "https://ducksnest-test-controlplane:6443";

  # Test VM: Set password for oriduckduck user
  users.users.oriduckduck = lib.mkForce {
    isNormalUser = true;
    description = "oriduckduck";
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "test";  # Simple password for testing
    packages = with pkgs; [];
  };

  # Allow sudo without password for testing (override common settings)
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # Test VM: Provide SSH private key for agenix decryption
  age.identityPaths = lib.mkForce [ "/root/.ssh/ducksnest_cert_mng_key_test_wn" ];

  # Test VM: Copy private key to standard location
  environment.etc."ssh/ducksnest_cert_mng_key_test_wn" = {
    source = ../../ssh-host-keys/ducksnest-test-worker-node/ducksnest_cert_mng_key_test_wn;
    mode = "0600";
    user = "root";
  };

  system.stateVersion = "25.05";
}
