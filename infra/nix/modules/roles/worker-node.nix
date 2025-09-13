{ config, pkgs, ... }:

{
  virtualisation.cri-o = {
    enable = true;
    settings.crio.network.network_dir = "";
    settings.crio.network.plugin_dirs = [];
  };

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
    masterAddress = "ducksnest-cp";
    clusterCidr = "10.244.0.0/16";
    
    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/crio/crio.sock";
    };
    
    proxy.enable = true;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "vm.max_map_count" = 262144;
  };

  boot.kernelModules = [ "overlay" "br_netfilter" ];
}