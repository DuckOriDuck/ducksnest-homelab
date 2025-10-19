{ config, pkgs, lib, ... }:

let
  secretsDir = "/var/lib/kubernetes/secrets";
in
{
  virtualisation.containerd.enable = true;

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
    #roles = ["master"];
    masterAddress = "127.0.0.1";
    clusterCidr = "10.244.0.0/16";
    
    apiserver = {
      enable = true;
      bindAddress = "0.0.0.0";
      extraSANs = ["ducksnest-controlplane"];
      clientCaFile = "${secretsDir}/ca.pem";
      tlsCertFile = "${secretsDir}/kube-apiserver.pem";
      tlsKeyFile = "${secretsDir}/kube-apiserver-key.pem";
      kubeletClientCertFile = "${secretsDir}/kube-apiserver-kubelet-client.pem";
      kubeletClientKeyFile = "${secretsDir}/kube-apiserver-kubelet-client-key.pem";
      serviceAccountKeyFile = "${secretsDir}/service-account.pem";
      serviceAccountSigningKeyFile = "${secretsDir}/service-account-key.pem";
      etcd = {
        servers = ["https://127.0.0.1:2379"];
        caFile = "${secretsDir}/ca.pem";
        certFile = "${secretsDir}/kube-apiserver-etcd-client.pem";
        keyFile = "${secretsDir}/kube-apiserver-etcd-client-key.pem";
      };
    };
    
    controllerManager = {
      enable = true;
      rootCaFile = "${secretsDir}/ca.pem";
      serviceAccountKeyFile = "${secretsDir}/service-account-key.pem";
      tlsCertFile = "${secretsDir}/kube-controller-manager.pem";
      tlsKeyFile = "${secretsDir}/kube-controller-manager-key.pem";
    };

    scheduler = {
      enable = true;
    };
    #easyCerts = true;
    
    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
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