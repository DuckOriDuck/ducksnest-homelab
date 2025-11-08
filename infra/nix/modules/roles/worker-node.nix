{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;
  calicoCniConfig = ./../../k8s/calico/10-calico.conflist;

  # Bootstrap scripts path
  bootstrapScripts = ./../../k8s/scripts;
in
{
  imports = [
    ../kubernetes-bootstrap.nix
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
    masterAddress =
      if config.networking.hostName == "ducksnest-test-worker-node"
      then "ducksnest-test-controlplane"
      else "ducksnest-laptop-firebat";
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
        server =
          if config.networking.hostName == "ducksnest-test-worker-node"
          then "https://10.100.0.2:6443"
          else "https://ducksnest-laptop-firebat:6443";
        caFile = caCert;
        certFile = certs.kubelet.path;
        keyFile = certs.kubelet.keyPath;
      };
      cni = {
        packages = [ pkgs.calico-cni-plugin ];
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
          (if config.networking.hostName == "ducksnest-test-worker-node"
           then "https://10.100.0.2:6443"
           else "https://ducksnest-laptop-firebat:6443")
          "ducksnest-k8s"
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
