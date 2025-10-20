{ lib, config, k8sRole ? "worker", ... }:
{
  certToolkit.dir = "./secrets/certs";

  # 인증서 생성 시 사용할 개인 비밀키
  certToolkit.userAgeIdentity = "$HOME/.ssh/ducksnest_cert_mng_key";

  # 인증서를 암호화할 공개키 (운영자)
  certToolkit.userAgeKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUJcgORZ6omxkAFFsHSvqYjrU/vEfwzMcw3TxjRmXHH operator@ducksnest"
  ];

  # 각 서버의 호스트 공개키 경로 (디렉토리 구조 + 커스텀 파일명)
  certToolkit.owningHostKey =
    let
      keyFileName = {
        "ducksnest-laptop-old" = "ducksnest_cert_mng_key_old.pub";
        "ducksnest-laptop-ultra" = "ducksnest_cert_mng_key_ultra.pub";
        "ducksnest-laptop-firebat" = "ducksnest_cert_mng_key_firebat.pub";
        "ducksnest-controlplane" = "ducksnest_cert_mng_key_ec2.pub";
      }.${config.networking.hostName} or "ssh_host_ed25519_key.pub";
    in
      "./ssh-host-keys/${config.networking.hostName}/${keyFileName}";

  # Default configuration (required by cert-toolkit)
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

  # Certificate Authority
  certToolkit.cas.k8s.ca = {
    usages = [ "signing" ];
    expiry = "876000h"; # 100 years
    commonName = "DucksNest Kubernetes Cluster CA";
  };

  certToolkit.cas.k8s.certs = lib.mkMerge [
    # Worker node certificates
    {
      kubelet = {
        commonName = "system:node:${config.networking.hostName}";
        hosts = [ config.networking.hostName "127.0.0.1" ];
        owner = "root";
        usages = [ "server auth" "client auth" ];
        expiry = "8760h";
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
        owner = "root";
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
        ];
        owner = "root";
        usages = [ "server auth" ];
        expiry = "8760h";
      };

      kube-apiserver-kubelet-client = {
        commonName = "kube-apiserver-kubelet-client";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-apiserver-etcd-client = {
        commonName = "kube-apiserver-etcd-client";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-controller-manager = {
        commonName = "system:kube-controller-manager";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-scheduler = {
        commonName = "system:kube-scheduler";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      kube-admin = {
        commonName = "kubernetes-admin";
        owner = "root";
        usages = [ "client auth" ];
        expiry = "8760h";
      };

      service-account = {
        commonName = "service-accounts";
        owner = "root";
        usages = [ "signing" ];
        expiry = "8760h";
      };
    })
  ];
}
