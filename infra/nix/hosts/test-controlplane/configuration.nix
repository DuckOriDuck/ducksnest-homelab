{ config, pkgs, lib, k8sRole ? "control-plane", ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/certs/ca.nix
    ../../modules/roles/control-plane.nix
  ];

  networking.hostName = "ducksnest-test-controlplane";
  networking.hostId = "12345678";
  networking.interfaces.eth0.useDHCP = true;

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
  age.identityPaths = lib.mkForce [ "/etc/ssh/ducksnest_cert_mng_key_test_cp" ];

  # Test VM: Place SSH private key in /etc (available during agenix phase)
  environment.etc."ssh/ducksnest_cert_mng_key_test_cp" = {
    source = ../../ssh-host-keys/ducksnest-test-controlplane/ducksnest_cert_mng_key_test_cp;
    mode = "0600";
    user = "root";
    group = "root";
  };

  system.stateVersion = "25.05";
}
