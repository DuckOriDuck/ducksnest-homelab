{ config, pkgs, ... }:

{
  virtualisation.cri-o = {
    enable = true;
    settings.crio.network.network_dir = "";
    settings.crio.network.plugin_dirs = [];
  };

  environment.systemPackages = with pkgs; [
    kubernetes
    kubernetes-helm
    kustomize
    k9s
    calico-cni-plugin
    cri-tools
    util-linux
    coreutils
    iproute2
    iptables
    ethtool
    socat
    awscli2
    jq
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
    roles = ["master"];
    masterAddress = "127.0.0.1";
    clusterCidr = "10.244.0.0/16";
    
    apiserver = {
      enable = true;
      bindAddress = "0.0.0.0";
    };
    
    controllerManager.enable = true;
    scheduler.enable = true;
    easyCerts = true;
    
    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/crio/crio.sock";
    };
    
    proxy.enable = true;
    addons.dns.enable = true;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "vm.max_map_count" = 262144;
  };

  boot.kernelModules = [ "overlay" "br_netfilter" ];

  environment.variables.KUBECONFIG = "/etc/kubernetes/admin.conf";
}