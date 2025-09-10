{ config, pkgs, ... }:

{
  # Worker node configuration for Kubernetes cluster
  
  # Enable container runtime
  virtualisation = {
    cri-o = {
      enable = true;
    };
  };

  # Network configuration for cluster
  networking = {
    firewall = {
      allowedTCPPorts = [
        22     # SSH
        10250  # kubelet API
        8472   # Flannel VXLAN
      ];
      allowedUDPPorts = [
        8472   # Flannel VXLAN
      ];
      allowedTCPPortRanges = [
        { from = 30000; to = 32767; }  # NodePort services
      ];
    };
  };

  # System packages for worker nodes
  environment.systemPackages = with pkgs; [
    # Container tools
    cri-o
    cri-tools
    
    # Kubernetes tools
    kubernetes
    kubectl
    k9s
    
    # Network tools
    flannel
    
    # Monitoring
    prometheus-node-exporter

    # git
    git

    #extra
    fastfetchMinimal
  ];

  # Services for worker nodes
  services = {
    # Node exporter for monitoring
    prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "filesystem" 
        "netdev"
        "meminfo"
        "cpu"
        "loadavg"
      ];
    };



  };

  # System tuning for Kubernetes
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  # Load required kernel modules
  boot.kernelModules = [ "br_netfilter" "overlay" ];
}