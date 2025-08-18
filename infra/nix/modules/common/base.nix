{ config, pkgs, ... }:

{
  # Base configuration for all homelab hosts
  # Note: Boot configuration moved to boot-uefi.nix or boot-bios.nix

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
      trusted-users = [ "root" "oriduckduck" "duck" ];
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