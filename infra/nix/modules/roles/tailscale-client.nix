{ config, pkgs, lib, ... }:

{
  environment.systemPackages = [ pkgs.unstable.tailscale ];
  services.tailscale = {
    enable = true;
    package = pkgs.unstable.tailscale;
  };
}
