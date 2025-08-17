{ config, pkgs, ... }:

{
  # Base configuration for all homelab hosts
  
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    # Enable kernel modules for containers
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    
    # Enable systemd in initrd for faster boot
    initrd.systemd.enable = true;
  };

  # Time and locale
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  # Network configuration
  networking = {
    networkmanager.enable = true;
    
    # Basic firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
    };
  };

  # Enable flakes and configure Nix
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "duck" ];
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # System configuration
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Basic shell aliases
  environment.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    grep = "grep --color=auto";
    ".." = "cd ..";
    "..." = "cd ../..";
  };
}