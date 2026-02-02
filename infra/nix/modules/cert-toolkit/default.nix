{ lib, config, pkgs, k8sRole ? "worker", ... }@args:
{
  # Import cert-toolkit module
  imports = [
    ./cert-toolkit.nix
  ];

  # CA Configuration
  certToolkit.dir = "./secrets/certs";


  certToolkit.userAgeIdentity = "$HOME/.ssh/ducksnest_cert_mng_key";


  certToolkit.userAgeKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUJcgORZ6omxkAFFsHSvqYjrU/vEfwzMcw3TxjRmXHH operator@ducksnest"
  ];


  certToolkit.owningHostKey =
    let
      keyFileName = {
        "ducksnest-laptop-old" = "ducksnest_cert_mng_key_old.pub";
        "ducksnest-laptop-ultra" = "ducksnest_cert_mng_key_ultra.pub";
        "ducksnest-laptop-firebat" = "ducksnest_cert_mng_key_firebat.pub";
        "ducksnest-controlplane" = "ducksnest_cert_mng_key_ec2.pub";
        "ducksnest-test-controlplane" = "ducksnest_cert_mng_key_test_cp.pub";
        "ducksnest-test-worker-node" = "ducksnest_cert_mng_key_test_wn.pub";
      }.${config.networking.hostName} or "ssh_host_ed25519_key.pub";
    in
      "./ssh-host-keys/${config.networking.hostName}/${keyFileName}";


  certToolkit.defaults = {
    key = {
      algo = "rsa";
      size = 2048;
    };
    hosts = [ ];  # Default empty, each cert overrides
    usages = [ ];  # Default empty, each cert overrides
    names = {
      C = null;
      ST = null;
      L = null;
      O = "DucksNest";
      OU = null;
    };
  };


  certToolkit.cas.k8s.ca = {
    usages = [ "signing" ];
    expiry = "876000h";
    commonName = "DucksNest Kubernetes Cluster CA";
  };

  certToolkit.cas.k8s.certs = lib.mkMerge [
    # Common certificates for all nodes
    {
      kubelet = {
        commonName = "system:node:${config.networking.hostName}";
        hosts = [ config.networking.hostName "127.0.0.1" ];
        owner = "root";
        usages = [ "server auth" "client auth" ];
        expiry = "8760h";
        names = {
          O = "system:nodes";
        };
      };

      calico-cni = {
        commonName = "calico-cni";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-proxy = {
        commonName = "system:kube-proxy";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
        names = {
          O = "system:node-proxier";
        };
      };
    }

    # Control plane certificates
    (lib.mkIf (k8sRole == "control-plane") {
      etcd-server = {
        commonName = "etcd";
        hosts = [ config.networking.hostName "127.0.0.1" "localhost" ];
        owner = "etcd";
        usages = [ "server auth" "client auth" ];
        expiry = "8760h";
      };

      etcd-peer = {
        commonName = "etcd-peer";
        hosts = [ config.networking.hostName "127.0.0.1" "localhost" ];
        owner = "etcd";
        usages = [ "server auth" "client auth" ];
        expiry = "8760h";
      };

      etcd-client = {
        commonName = "etcd-client";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-apiserver = {
        commonName = "kube-apiserver";
        hosts = [
          config.networking.hostName
          "127.0.0.1"
          "localhost"
          "kubernetes"
          "kubernetes.default"
          "kubernetes.default.svc"
          "kubernetes.default.svc.cluster.local"
          "10.96.0.1"
        ] ++ (if config.networking.hostName == "ducksnest-test-controlplane" then [ "10.100.0.2" ] else []);
        owner = "kubernetes";
        usages = [ "server auth" ];
        expiry = "8760h";
      };

      kube-apiserver-kubelet-client = {
        commonName = "kube-apiserver-kubelet-client";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-apiserver-etcd-client = {
        commonName = "kube-apiserver-etcd-client";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-controller-manager = {
        commonName = "system:kube-controller-manager";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-scheduler = {
        commonName = "system:kube-scheduler";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-admin = {
        commonName = "kubernetes-admin";
        owner = "kubernetes";
        usages = [ "client auth" ];
        expiry = "8760h";
        names = {
          O = "system:masters";
        };
      };

      service-account = {
        commonName = "service-accounts";
        owner = "kubernetes";
        usages = [ "signing" ];
        expiry = "8760h";
      };
    })
  ];
}
