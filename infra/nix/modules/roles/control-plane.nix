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

  systemd.services.generate-admin-kubeconfig = {
    description = "Generate admin kubeconfig";
    wantedBy = [ "multi-user.target" ];
    after = [ "agenix.service" "kube-apiserver.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /etc/kubernetes
      cat > /etc/kubernetes/cluster-admin.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${caCert}
    server: https://127.0.0.1:6443
  name: ducksnest-k8s
contexts:
- context:
    cluster: ducksnest-k8s
    user: kubernetes-admin
  name: default
current-context: default
users:
- name: kubernetes-admin
  user:
    client-certificate: ${certs.kube-admin.path}
    client-key: ${certs.kube-admin.keyPath}
EOF
      chmod 600 /etc/kubernetes/cluster-admin.kubeconfig
      echo "Admin kubeconfig generated at /etc/kubernetes/cluster-admin.kubeconfig"
    '';
  };

  environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
}
