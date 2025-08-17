{ config, pkgs, ... }:

{
  # User configuration for all homelab hosts

  # Main user configuration
  users.users.duck = {
    isNormalUser = true;
    description = "Duck - Homelab Admin";
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "docker" 
      "libvirtd"
      "systemd-journal"
    ];
    
    # Basic user packages
    packages = with pkgs; [
      firefox
      git
      vim
      tmux
      htop
    ];
    
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx duck@homelab"
    ];
  };

  # Groups
  users.groups = {
    homelab = {};
  };
}