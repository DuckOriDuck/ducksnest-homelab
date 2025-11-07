{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;

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

  services.etcd = {
    enable = true;
    listenClientUrls = ["https://127.0.0.1:2379"];
    advertiseClientUrls = ["https://127.0.0.1:2379"];
    certFile = certs.etcd-server.path;
    keyFile = certs.etcd-server.keyPath;
    trustedCaFile = caCert;
  };

  environment.systemPackages = with pkgs; [
    kubernetes
    kubernetes-helm
    kustomize
    k9s
    cri-tools
    calicoctl
    calico-cni-plugin
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
    btop
    tree
    vim
    fastfetchMinimal
  ];

  services.kubernetes = {
    masterAddress = config.networking.hostName;
    clusterCidr = "10.244.0.0/16";

    apiserver = {
      enable = true;
      bindAddress = "0.0.0.0";
      allowPrivileged = true;
      extraSANs = [
        config.networking.hostName
        "kubernetes"
        "kubernetes.default"
        "kubernetes.default.svc"
        "kubernetes.default.svc.cluster.local"
      ];
      clientCaFile = caCert;
      tlsCertFile = certs.kube-apiserver.path;
      tlsKeyFile = certs.kube-apiserver.keyPath;
      kubeletClientCertFile = certs.kube-apiserver-kubelet-client.path;
      kubeletClientKeyFile = certs.kube-apiserver-kubelet-client.keyPath;
      serviceAccountKeyFile = certs.service-account.path;
      serviceAccountSigningKeyFile = certs.service-account.keyPath;
      etcd = {
        servers = ["https://127.0.0.1:2379"];
        caFile = caCert;
        certFile = certs.kube-apiserver-etcd-client.path;
        keyFile = certs.kube-apiserver-etcd-client.keyPath;
      };
    };
    
    controllerManager = {
      enable = true;
      rootCaFile = caCert;
      serviceAccountKeyFile = certs.service-account.keyPath;
      tlsCertFile = certs.kube-controller-manager.path;
      tlsKeyFile = certs.kube-controller-manager.keyPath;
      kubeconfig = {
        server = "https://${config.networking.hostName}:6443";
        caFile = caCert;
        certFile = certs.kube-controller-manager.path;
        keyFile = certs.kube-controller-manager.keyPath;
      };
    };

    scheduler = {
      enable = true;
      kubeconfig = {
        server = "https://${config.networking.hostName}:6443";
        caFile = caCert;
        certFile = certs.kube-scheduler.path;
        keyFile = certs.kube-scheduler.keyPath;
      };
    };
    
    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
      taints = {
        master = {
          key = "node-role.kubernetes.io/control-plane";
          value = "true";
          effect = "NoSchedule";
        };
      };
      clientCaFile = caCert;
      tlsCertFile = certs.kubelet.path;
      tlsKeyFile = certs.kubelet.keyPath;
      kubeconfig = {
        server = "https://${config.networking.hostName}:6443";
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

    proxy.enable = false;
    addons.dns.enable = true;
    
    flannel.enable = false;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "vm.max_map_count" = 262144;
  };

  boot.kernelModules = [ "overlay" "br_netfilter" ];
  boot.kernelPackages = pkgs.linuxPackages;

  # Create writable directory for CNI configuration
  systemd.tmpfiles.rules = [
    "d /var/lib/cni/net.d 0755 root root -"
  ];

  # Kubernetes bootstrap configuration
  kubernetes.bootstrap = {
    enable = true;

    tasks = {
      generate-kubeconfig = {
        description = "Generate admin kubeconfig";
        script = "${bootstrapScripts}/generate-admin-kubeconfig.sh";
        args = [
          "/etc/kubernetes/cluster-admin.kubeconfig"
          caCert
          certs.kube-admin.path
          certs.kube-admin.keyPath
          "https://${config.networking.hostName}:6443"
          "ducksnest-k8s"
          "kubernetes-admin"
        ];
        after = [ "agenix.service" "kube-apiserver.service" ];
      };

      generate-cni-kubeconfig = {
        description = "Generate CNI kubeconfig";
        script = "${bootstrapScripts}/generate-cni-kubeconfig.sh";
        args = [
          "/var/lib/cni/net.d/calico-kubeconfig"
          caCert
          certs.calico-cni.path
          certs.calico-cni.keyPath
          "https://${config.networking.hostName}:6443"
          "ducksnest-k8s"
          "calico-cni"
        ];
        after = [ "agenix.service" "kube-apiserver.service" ];
      };

      bootstrap-rbac = {
        description = "Bootstrap Kubernetes RBAC rules";
        script = "${bootstrapScripts}/bootstrap-rbac.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          caCert
          "https://${config.networking.hostName}:6443"
          "/etc/kubernetes/rbac"
          "30"
          "2"
        ];
        after = [ "k8s-bootstrap-generate-kubeconfig.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
        preStart = ''
          # Copy RBAC manifests to standard location
          mkdir -p /etc/kubernetes/rbac
          cp -r ${./../../k8s/rbac}/* /etc/kubernetes/rbac/ 2>/dev/null || true
        '';
      };
    };
  };

  environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
}
