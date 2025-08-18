{ config, pkgs, ... }:

{
  # BIOS/MBR boot configuration for legacy systems
  
  boot = {
    loader = {
      grub = {
        enable = true;
        # device will be set in individual host configuration
        # device = "/dev/sda";  # Set this in host-specific config
        useOSProber = true;  # Detect other operating systems
      };
      timeout = 3;
    };
  };
}