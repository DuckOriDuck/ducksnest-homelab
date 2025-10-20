{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;
in
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
    masterAddress = "ducksnest-laptop-firebat";
    clusterCidr = "10.244.0.0/16";

    kubelet = {
      enable = true;
      registerNode = true;
      unschedulable = false;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
      clientCaFile = caCert;
      tlsCertFile = certs.kubelet.path;
      tlsKeyFile = certs.kubelet.keyPath;
      kubeconfig = {
        server = "https://ducksnest-laptop-firebat:6443";
        caFile = caCert;
        certFile = certs.kubelet.path;
        keyFile = certs.kubelet.keyPath;
      };
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