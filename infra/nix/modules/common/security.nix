{ config, pkgs, ... }:

{

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowUsers = [ "duck" "oriduckduck" "remoteduckduck" ];
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # AppArmor for additional security
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    maxretry = 3;
  };

  # Additional security packages
  environment.systemPackages = with pkgs; [
    gnupg
    age
    sops
  ];
}