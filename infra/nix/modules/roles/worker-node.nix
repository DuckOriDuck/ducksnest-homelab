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
    btop
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
      clusterDns = [ "10.96.0.10" ];
      clientCaFile = caCert;
      tlsCertFile = certs.kubelet.path;
      tlsKeyFile = certs.kubelet.keyPath;
      nodeIp = "\${NODE_IP}";
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
            mtu = 1230;
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

    # Disable systemd kube-proxy (using DaemonSet instead)
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
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
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
        script = "${bootstrapScripts}/generate-kubeconfig.sh";
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

      generate-kube-proxy-kubeconfig = {
        description = "Generate kube-proxy kubeconfig for worker node";
        preStart = ''
          mkdir -p /etc/kubernetes/pki
          cp ${caCert} /etc/kubernetes/pki/ca.crt
          cp ${certs.kube-proxy.path} /etc/kubernetes/pki/kube-proxy.crt
          cp ${certs.kube-proxy.keyPath} /etc/kubernetes/pki/kube-proxy.key
        '';
        script = "${bootstrapScripts}/generate-kubeconfig.sh";
        args = [
          "/etc/kubernetes/kube-proxy.kubeconfig"
          "/etc/kubernetes/pki/ca.crt"
          "/etc/kubernetes/pki/kube-proxy.crt"
          "/etc/kubernetes/pki/kube-proxy.key"
          "https://${cluster.network.apiServerAddress.workers}:${toString cluster.controlPlane.apiServerPort}"
          cluster.name
          "kube-proxy"
        ];
        after = [ "agenix.service" ];
      };
    };
  };

  systemd.services.kubelet = {
    after = [
      "network-online.target"
      "containerd.service"
      "k8s-bootstrap-generate-cni-kubeconfig.service"
      "k8s-bootstrap-generate-kube-proxy-kubeconfig.service"
    ];
    wants = [
      "network-online.target"
    ];

    path = with pkgs; [ iproute2 gnugrep gawk coreutils ];

    preStart = ''
      echo "Detecting node IP from LAN interface..."
      for i in {1..30}; do
        # Detect IP from first non-loopback, non-container interface
        NODE_IP=$(ip -4 addr show scope global | grep 'inet ' | grep -v 'docker\|veth\|cni\|flannel\|br-' | head -1 | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$NODE_IP" ]; then
          echo "NODE_IP=$NODE_IP" > /run/kubelet-env
          echo "Detected node IP: $NODE_IP"
          exit 0
        fi
        sleep 2
      done
      echo "Error: Failed to detect node IP after 60 seconds."
      exit 1
    '';

    serviceConfig = {
      EnvironmentFile = "-/run/kubelet-env";
      RestartSec = lib.mkForce "5s";
    };
  };
}
