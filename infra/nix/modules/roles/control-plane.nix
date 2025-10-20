{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;
in
{
  virtualisation.containerd.enable = true;

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
    btop
    tree
    vim
    fastfetchMinimal
  ];

  services.kubernetes = {
    masterAddress = "127.0.0.1";
    clusterCidr = "10.244.0.0/16";

    apiserver = {
      enable = true;
      bindAddress = "0.0.0.0";
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
    };

    scheduler = {
      enable = true;
      kubeconfig = {
        server = "https://127.0.0.1:6443";
        caFile = caCert;
        certFile = certs.kube-scheduler.path;
        keyFile = certs.kube-scheduler.keyPath;
      };
    };
    
    kubelet = {
      enable = true;
      registerNode = true;
      unschedulable = true;
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
        server = "https://127.0.0.1:6443";
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

  systemd.services.setup-kubeconfig = {
    description = "Setup kubernetes admin config symlink";
    wantedBy = [ "multi-user.target" ];
    after = [ "kube-controller-manager.service" "kube-scheduler.service" "kubelet.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      pick(){
        ${pkgs.systemd}/bin/systemctl show "$1" -p ExecStart --value 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -n "s/.*--kubeconfig=\([^ ]*\).*/\1/p"
      }
      for u in kube-controller-manager kube-scheduler kube-proxy kubelet; do
        p="$(pick "$u")"
        if [ -n "$p" ] && [ -f "$p" ]; then
          mkdir -p /etc/kubernetes
          ln -sf "$p" /etc/kubernetes/admin.conf
          echo "linked: /etc/kubernetes/admin.conf -> $p"
          exit 0
        fi
      done
      echo "Could not find kubeconfig in any systemd unit."; exit 1
    '';
  };

  environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
}