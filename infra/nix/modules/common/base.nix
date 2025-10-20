{ config, pkgs, ... }:

{
  age.identityPaths = [ "/root/.ssh/ducksnest_cert_mng_key" ];

  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "oriduckduck" "duck" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    grep = "grep --color=auto";
    ".." = "cd ..";
    "..." = "cd ../..";
  };
}