{ config, pkgs, lib, ... }:

{
  virtualisation.containerd.enable = true;
  

  environment.systemPackages = with pkgs; [
    kubernetes
    k9s
    calico-cni-plugin
    cri-tools
    util-linux
    coreutils
    iproute2
    iptables
    ethtool
    socat
    git
    curl
    wget
    unzip
    htop
    tree
    vim
    fastfetchMinimal
  ];

  services.kubernetes = {
    roles = ["node"];
    masterAddress = "ducksnest-controlplane";
    clusterCidr = "10.244.0.0/16";
    easyCerts = true;

    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
      cni = {
        packages = with pkgs; [ calico-cni-plugin cni-plugins ];
        config = [{
          name = "calico";
          cniVersion = "0.4.0";
          type = "calico";
          ipam = {
            type = "calico-ipam";
          };
        }];
      };
    };

    flannel.enable = false;
    proxy.enable = false;
    apiserver.enable = false;
    controllerManager.enable = false; 
    scheduler.enable = false;
    addons.dns.enable = false;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "vm.max_map_count" = 262144;
  };

  boot.kernelModules = [ "overlay" "br_netfilter" ];

  systemd.services = {
    kubelet.after = [ "tailscaled.service" "containerd.service" ];
  };
}