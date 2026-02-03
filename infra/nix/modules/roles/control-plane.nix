{ config, pkgs, lib, ... }:

let
  # Certificate paths from certToolkit
  caCert = config.certToolkit.cas.k8s.ca.path;
  certs = config.certToolkit.cas.k8s.certs;

  # Cluster configuration shorthand
  cluster = config.cluster;

  # Bootstrap scripts path
  bootstrapScripts = ./../../k8s/scripts;
  calicoCniConfig = ./../../k8s/calico/10-calico.conflist;
  calicoIpPool = ./../../k8s/calico/ip-pool.yaml;
  calicoCrds = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/crds.yaml";
    sha256 = "1620ee6f539de44bbb3ec4aa3c2687b5023d4ee30795b30663ab3423b0c5f5d5";
  };

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
    calico-kube-controllers
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
    fluxcd
  ];

  services.kubernetes = {
    masterAddress = cluster.controlPlane.hostname;
    clusterCidr = cluster.network.podCIDR;

    apiserver = {
      enable = true;
      bindAddress = cluster.controlPlane.bindAddress;
      advertiseAddress = "\${NODE_IP}";
      allowPrivileged = true;
      serviceClusterIpRange = config.cluster.network.serviceCIDR;
      extraSANs = [
        config.networking.hostName
        "127.0.0.1"
        "localhost"
        "192.168.0.15"
        "kubernetes"
        "kubernetes.default"
        "kubernetes.default.svc"
        "kubernetes.default.svc.cluster.local"
        "10.96.0.1"
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
        server = "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}";
        caFile = caCert;
        certFile = certs.kube-controller-manager.path;
        keyFile = certs.kube-controller-manager.keyPath;
      };
    };

    scheduler = {
      enable = true;
      kubeconfig = {
        server = "https://127.0.0.1:${toString cluster.controlPlane.apiServerPort}";
        caFile = caCert;
        certFile = certs.kube-scheduler.path;
        keyFile = certs.kube-scheduler.keyPath;
      };
    };

    kubelet = {
      enable = true;
      registerNode = true;
      containerRuntimeEndpoint = "unix:///var/run/containerd/containerd.sock";
      clusterDns = [ "10.96.0.10" ];
      # No taints - control plane also serves as worker node
      clientCaFile = caCert;
      tlsCertFile = certs.kubelet.path;
      tlsKeyFile = certs.kubelet.keyPath;
      nodeIp = "\${NODE_IP}";
      kubeconfig = {
        server = "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}";
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

    # Disable systemd kube-proxy (using DaemonSet instead)
    proxy.enable = false;

    addons.dns.enable = true;

    flannel.enable = false;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "vm.max_map_count" = 262144;
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
  };

  boot.kernelModules = [ "overlay" "br_netfilter" ];
  boot.kernelPackages = pkgs.linuxPackages;

  # Create writable directory for CNI configuration
  systemd.tmpfiles.rules = [
    "d /var/lib/cni/net.d 0755 root root -"
    "C /var/lib/cni/net.d/10-calico.conflist 0644 root root - ${calicoCniConfig}"
  ];

  # Kubernetes bootstrap configuration
  kubernetes.bootstrap = {
    enable = true;

    tasks = {
      generate-kubeconfig = {
        description = "Generate admin kubeconfig";
        script = "${bootstrapScripts}/generate-kubeconfig.sh";
        args = [
          "/etc/kubernetes/cluster-admin.kubeconfig"
          caCert
          certs.kube-admin.path
          certs.kube-admin.keyPath
          "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}"
          cluster.name
          "kubernetes-admin"
        ];
        after = [ "agenix.service" "kube-apiserver.service" ];
      };

      generate-cni-kubeconfig = {
        description = "Generate CNI kubeconfig";
        script = "${bootstrapScripts}/generate-kubeconfig.sh";
        args = [
          "/var/lib/cni/net.d/calico-kubeconfig"
          caCert
          certs.calico-cni.path
          certs.calico-cni.keyPath
          "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}"
          cluster.name
          "calico-cni"
        ];
        after = [ "agenix.service" "kube-apiserver.service" ];
      };

      generate-kube-proxy-kubeconfig = {
        description = "Generate kube-proxy kubeconfig for control plane";
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
          "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}"
          cluster.name
          "kube-proxy"
        ];
        after = [ "agenix.service" ];
      };

      bootstrap-rbac = {
        description = "Bootstrap Kubernetes RBAC rules";
        script = "${bootstrapScripts}/bootstrap-rbac.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          caCert
          "https://${cluster.network.apiServerAddress.controlPlane}:${toString cluster.controlPlane.apiServerPort}"
          "/etc/kubernetes/rbac"
          "60"
          "5"
        ];
        after = [ 
          "k8s-bootstrap-generate-kubeconfig.service"
          "k8s-bootstrap-generate-kube-proxy-kubeconfig.service"
          "k8s-bootstrap-generate-cni-kubeconfig.service"
          "kube-apiserver.service" 
          ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
        preStart = ''
          # Copy RBAC manifests to standard location
          mkdir -p /etc/kubernetes/rbac
          cp -r ${./../../k8s/rbac}/* /etc/kubernetes/rbac/ 2>/dev/null || true
        '';
      };

      calico-crds = {
        description = "Install Calico CRDs";
        script = "${bootstrapScripts}/apply-manifests.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          "${calicoCrds}"
        ];
        after = [ "k8s-bootstrap-bootstrap-rbac.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
      };

      calico-ip-pool = {
        description = "Configure Calico VXLAN IP pool";
        script = "${bootstrapScripts}/apply-manifests.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          "${calicoIpPool}"
        ];
        after = [ "k8s-bootstrap-calico-crds.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
      };

      calico-node = {
        description = "Deploy Calico Node DaemonSet";
        script = "${bootstrapScripts}/apply-manifests.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          "${./../../k8s/kube-system/calico-node.yaml}"
        ];
        after = [ "k8s-bootstrap-bootstrap-rbac.service" "k8s-bootstrap-calico-ip-pool.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
      };

      kube-proxy-daemonset = {
        description = "Deploy kube-proxy DaemonSet";
        script = "${bootstrapScripts}/apply-manifests.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          "${./../../k8s/kube-system/kube-proxy.yaml}"
        ];
        after = [ "k8s-bootstrap-bootstrap-rbac.service" "k8s-bootstrap-generate-kube-proxy-kubeconfig.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
      };

      coredns = {
        description = "Deploy CoreDNS";
        script = "${bootstrapScripts}/apply-manifests.sh";
        args = [
          "${pkgs.kubernetes}/bin/kubectl"
          "${./../../k8s/kube-system/coredns.yaml}"
        ];
        after = [ "k8s-bootstrap-bootstrap-rbac.service" ];
        environment = {
          KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";
        };
      };
    };
  };

  environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";

  # kube-apiserver needs Tailscale IP for advertiseAddress
  systemd.services.kube-apiserver = {
    after = [ "tailscaled.service" "etcd.service" ];
    wants = [ "tailscaled.service" ];

    path = with pkgs; [ iproute2 gnugrep gawk coreutils ];

    preStart = lib.mkBefore ''
      echo "Waiting for tailscale0 interface for API server..."
      for i in {1..30}; do
        if ip addr show tailscale0 >/dev/null 2>&1; then
          NODE_IP=$(ip -4 addr show tailscale0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
          if [ -n "$NODE_IP" ]; then
            echo "NODE_IP=$NODE_IP" > /run/kube-apiserver/env
            echo "Successfully detected Tailscale IP for API server: $NODE_IP"
            exit 0
          fi
        fi
        sleep 2
      done
      echo "Error: Failed to detect Tailscale IP after 60 seconds."
      exit 1
    '';

    serviceConfig = {
      RuntimeDirectory = "kube-apiserver";
      EnvironmentFile = "-/run/kube-apiserver/env";
    };
  };

  systemd.services.kubelet = {
    after = [ "network-online.target" "k8s-bootstrap-generate-kube-proxy-kubeconfig.service"];
    wants = [ "network-online.target" ];

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
