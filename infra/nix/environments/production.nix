{ ... }:

{
  cluster = {
    name = "ducksnest-k8s";
    environment = "production";
    domain = "cluster.local";

    network = {
      podCIDR = "10.244.0.0/16";
      serviceCIDR = "10.0.0.0/16";
      nodeNetwork = "192.168.1.0/24";

      apiServerAddress = {
        controlPlane = "127.0.0.1";
        workers = "ducksnest-controlplane";
      };
    };

    controlPlane = {
      hostname = "ducksnest-controlplane";
      apiServerPort = 6443;
      bindAddress = "0.0.0.0";
    };

    cni = {
      provider = "calico";
      calico = {
        vxlanMode = "CrossSubnet";
        ipAutodetectionMethod = "cidr=192.168.1.0/24";
      };
    };
  };
}