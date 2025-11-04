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

  # Static IP for bridged networking between VMs
  networking.interfaces.eth0 = {
    ipv4.addresses = [{
      address = "10.100.0.2";
      prefixLength = 24;
    }];
  };
  networking.defaultGateway = "10.100.0.1";
  networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];

  networking.firewall.allowedTCPPorts = lib.mkAfter [
    6443  # Kubernetes API server
    2379 2380  # etcd client/peer ports
    10250 10257 10259  # kubelet/manager/scheduler webhook ports
  ];
  networking.firewall.allowedUDPPorts = lib.mkAfter [
    8472  # VXLAN for Calico/Flannel if enabled
  ];

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
  security.apparmor.enable = lib.mkForce false;
  services.fail2ban.enable = lib.mkForce false;

  # SSH: Enable password authentication for testing
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;

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
  
  # 부팅 시 커널과 로그인 콘솔을 직렬로 보냄
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  # 직렬 getty 활성화 → ttyS0에 로그인 프롬프트 표시
  systemd.services."serial-getty@ttyS0".enable = true;

  # (선택) 부팅 로그 상세도 높이기
  boot.consoleLogLevel = 7;
  system.stateVersion = "25.05";
}