{ lib, ... }:

{
  options.cluster = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Kubernetes cluster name";
      example = "ducksnest-k8s";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Cluster domain for DNS";
      default = "cluster.local";
    };

    environment = lib.mkOption {
      type = lib.types.enum [ "test" "production" ];
      description = "Cluster environment type";
      example = "test";
    };

    network = {
      podCIDR = lib.mkOption {
        type = lib.types.str;
        description = "Pod network CIDR";
        example = "10.244.0.0/16";
      };

      serviceCIDR = lib.mkOption {
        type = lib.types.str;
        description = "Service network CIDR";
        example = "10.0.0.0/16";
      };

      nodeNetwork = lib.mkOption {
        type = lib.types.str;
        description = "Node network CIDR";
        example = "10.100.0.0/24";
      };

      dnsServiceIP = lib.mkOption {
        type = lib.types.str;
        description = "Cluster DNS service IP";
        example = "10.0.0.10";
      };

      apiServerIP = lib.mkOption {
        type = lib.types.str;
        description = "API server service IP";
        default = "10.0.0.1";
      };
    };

    controlPlane = {
      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Control plane hostname";
        example = "ducksnest-controlplane";
      };

      ipAddress = lib.mkOption {
        type = lib.types.str;
        description = "Control plane IP address";
        example = "10.100.0.2";
      };

      apiServerPort = lib.mkOption {
        type = lib.types.int;
        description = "API server port";
        default = 6443;
      };

      bindAddress = lib.mkOption {
        type = lib.types.str;
        description = "API server bind address";
        default = "0.0.0.0";
      };
    };

    workerNodes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "Worker node hostname";
          };

          ipAddress = lib.mkOption {
            type = lib.types.str;
            description = "Worker node IP address";
          };
        };
      });
      default = [];
      description = "List of worker nodes";
      example = [
        { hostname = "worker-1"; ipAddress = "10.100.0.3"; }
        { hostname = "worker-2"; ipAddress = "10.100.0.4"; }
      ];
    };

    cni = {
      provider = lib.mkOption {
        type = lib.types.enum [ "calico" "flannel" ];
        description = "CNI provider";
        default = "calico";
      };

      calico = {
        vxlanEnabled = lib.mkOption {
          type = lib.types.bool;
          description = "Enable VXLAN mode for Calico";
          default = true;
        };

        ipAutodetectionMethod = lib.mkOption {
          type = lib.types.str;
          description = "IP autodetection method for Calico";
          default = "first-found";
        };
      };
    };
  };
}
