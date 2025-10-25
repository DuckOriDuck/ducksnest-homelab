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

  # Static IP for bridged networking between VMs
  networking.interfaces.eth0 = {
    ipv4.addresses = [{
      address = "10.100.0.3";
      prefixLength = 24;
    }];
  };
  networking.defaultGateway = "10.100.0.1";
  networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];

  # Add host entry for control plane so DNS resolution works
  networking.extraHosts = "10.100.0.2 ducksnest-test-controlplane";

  # Override master address for test environment to use hostname
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
  # Use /etc/ssh path since environment.etc runs before agenix
  age.identityPaths = lib.mkForce [ "/etc/ssh/ducksnest_cert_mng_key_test_wn" ];

  # Test VM: Place SSH private key in /etc (available during agenix phase)
  environment.etc."ssh/ducksnest_cert_mng_key_test_wn" = {
    source = ../../ssh-host-keys/ducksnest-test-worker-node/ducksnest_cert_mng_key_test_wn;
    mode = "0600";
    user = "root";
    group = "root";
  };

  system.stateVersion = "25.05";
}
