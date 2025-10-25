# Minimal hardware configuration for QEMU/KVM test VM
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/boot/boot-uefi.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  time.timeZone = "Asia/Seoul";
}
