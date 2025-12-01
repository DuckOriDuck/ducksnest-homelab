{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;
  calicoCniConfig = ./../../k8s/calico/10-calico.conflist;

  # Cluster configuration shorthand
  cluster = config.cluster;

  # Bootstrap scripts path
  bootstrapScripts = ./../../k8s/scripts;

  # Custom calico package with calico-ipam binary
  calicoWithIpam = pkgs.runCommand "calico-cni-with-ipam" {} ''
    mkdir -p $out/bin
    cp -r ${pkgs.calico-cni-plugin}/bin/* $out/bin/
    # calico-ipam is the same binary as calico
    cp $out/bin/calico $out/bin/calico-ipam
  '';
in
{
  imports = [
    ../kubernetes-bootstrap.nix
    ../cluster-config.nix
  ];
  virtualisation.containerd = {
    enable = true;
    settings = {
      plugins."io.containerd.grpc.v1.cri" = {
        sandbox_image = "registry.k8s.io/pause:3.9";
      };
    };
  };
  

  environment.systemPackages = with pkgs; [
    kubernetes
    k9s
    cri-tools
    calico-cni-plugin
    calico-kube-controllers
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
    masterAddress = cluster.controlPlane.hostname;
    clusterCidr = cluster.network.podCIDR;

    kubelet = {
      enable = true;
      registerNode = true;
      unschedulable = false;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
      clientCaFile = caCert;
      tlsCertFile = certs.kubelet.path;
      tlsKeyFile = certs.kubelet.keyPath;
      kubeconfig = {
        server = "https://${cluster.network.apiServerAddress.workers}:${toString cluster.controlPlane.apiServerPort}";
        caFile = caCert;
        certFile = certs.kubelet.path;
        keyFile = certs.kubelet.keyPath;
      };
      cni = {
        packages = [ calicoWithIpam ];
        config = [
          {
            type = "calico";
            name = "k8s-pod-network";
            cniVersion = "0.3.1";
            log_level = "info";
            datastore_type = "kubernetes";
            mtu = 1500;
            ipam = {
              type = "calico-ipam";
            };
            policy = {
              type = "k8s";
            };
            kubernetes = {
              kubeconfig = "/var/lib/cni/net.d/calico-kubeconfig";
            };
          }
        ];
      };
    };

    flannel.enable = false;

    # Enable kube-proxy for service networking
    proxy = {
      enable = true;
      kubeconfig = {
        server = "https://${cluster.network.apiServerAddress.workers}:${toString cluster.controlPlane.apiServerPort}";
        caFile = caCert;
        certFile = certs.kube-proxy.path;
        keyFile = certs.kube-proxy.keyPath;
      };
    };

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

  systemd.tmpfiles.rules = [
    "d /var/lib/cni/net.d 0755 root root -"
    "C /var/lib/cni/net.d/10-calico.conflist 0644 root root - ${calicoCniConfig}"
  ];

  # Kubernetes bootstrap configuration
  kubernetes.bootstrap = {
    enable = true;

    tasks = {
      generate-cni-kubeconfig = {
        description = "Generate CNI kubeconfig for worker node";
        script = "${bootstrapScripts}/generate-cni-kubeconfig.sh";
        args = [
          "/var/lib/cni/net.d/calico-kubeconfig"
          caCert
          certs.calico-cni.path
          certs.calico-cni.keyPath
          "https://${cluster.network.apiServerAddress.workers}:${toString cluster.controlPlane.apiServerPort}"
          cluster.name
          "calico-cni"
        ];
        after = [ "agenix.service" ];
      };
    };
  };

  systemd.services = {
    kubelet.after = [ "tailscaled.service" "containerd.service" "k8s-bootstrap-generate-cni-kubeconfig.service" ];
  };
}
