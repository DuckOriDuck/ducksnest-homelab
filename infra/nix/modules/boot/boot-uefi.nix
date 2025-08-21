{ config, pkgs, ... }:

{
  # UEFI boot configuration for modern systems
  
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    # Enable systemd in initrd for faster boot
    initrd.systemd.enable = true;
  };
}