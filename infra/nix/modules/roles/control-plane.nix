{ config, pkgs, lib, ... }:

{
  virtualisation.cri-o.enable = true;
  
  environment.etc."cni/net.d/10-crio-bridge.conflist".enable = lib.mkForce false;
  environment.etc."cni/net.d/99-loopback.conflist".enable = lib.mkForce false;

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
      clientCaFile = "/var/lib/kubernetes/secrets/ca.pem";
      tlsCertFile = "/var/lib/kubernetes/secrets/kube-apiserver.pem";
      tlsKeyFile = "/var/lib/kubernetes/secrets/kube-apiserver-key.pem";
      kubeletClientCertFile = "/var/lib/kubernetes/secrets/kube-apiserver-kubelet-client.pem";
      kubeletClientKeyFile = "/var/lib/kubernetes/secrets/kube-apiserver-kubelet-client-key.pem";
      serviceAccountKeyFile = "/var/lib/kubernetes/secrets/service-account.pem";
      serviceAccountSigningKeyFile = "/var/lib/kubernetes/secrets/service-account-key.pem";
      etcd = {
        servers = ["https://127.0.0.1:2379"];
        caFile = "/var/lib/kubernetes/secrets/ca.pem";
        certFile = "/var/lib/kubernetes/secrets/kube-apiserver-etcd-client.pem";
        keyFile = "/var/lib/kubernetes/secrets/kube-apiserver-etcd-client-key.pem";
      };
    };
    
    controllerManager = {
      enable = true;
      rootCaFile = "/var/lib/kubernetes/secrets/ca.pem";
      serviceAccountKeyFile = "/var/lib/kubernetes/secrets/service-account-key.pem";
      tlsCertFile = "/var/lib/kubernetes/secrets/kube-controller-manager.pem";
      tlsKeyFile = "/var/lib/kubernetes/secrets/kube-controller-manager-key.pem";
    };

    scheduler = {
      enable = true;
    };
    easyCerts = true;
    
    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/crio/crio.sock";
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

  environment.variables.KUBECONFIG = "/etc/kubernetes/admin.conf";
}