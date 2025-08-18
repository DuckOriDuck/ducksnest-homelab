{ config, pkgs, ... }:

{
  # Common user definitions for all homelab hosts
  
  users.users = {
    # Main user account (used on laptops)
    oriduckduck = {
      isNormalUser = true;
      description = "oriduckduck";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [];
    };

    # SSH remote access user (used on laptops)
    remoteduckduck = {
      isNormalUser = true;
      description = "ssh-remote-user";
      extraGroups = [ "wheel" ];
      packages = with pkgs; [];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL65XU0JgCzWVrM4S25tZb50r40rpzPy0GWMFF/AgjXY seocd777@gmail.com"
      ];
    };

    # Service user for homelab automation (used on servers)
    duck = {
      isNormalUser = true;
      description = "Duck - Homelab Admin";
      extraGroups = [ 
        "networkmanager" 
        "wheel" 
        "docker" 
        "libvirtd"
        "systemd-journal"
      ];
      
      packages = with pkgs; [
        git
        vim
        tmux
        htop
      ];
      
      openssh.authorizedKeys.keys = [
        ""
      ];
    };
  };

  # Groups
  users.groups = {
    homelab = {};
  };

  # Security configuration
  security.sudo = {
    enable = true;
    # Individual hosts can override wheelNeedsPassword
    wheelNeedsPassword = true;  # Default: require password
  };
}