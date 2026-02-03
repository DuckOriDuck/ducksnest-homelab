{ ... }:

{
  cluster = {
    name = "ducksnest-k8s";
    environment = "production";
    domain = "cluster.local";

    network = {
      podCIDR = "10.244.0.0/16";
      serviceCIDR = "10.96.0.0/12";
      nodeNetwork = "192.168.0.0/24";

      apiServerAddress = {
        controlPlane = "127.0.0.1";
        workers = "192.168.0.15";
      };
    };

    controlPlane = {
      hostname = "ducksnest-laptop-firebat";
      apiServerPort = 6443;
      bindAddress = "0.0.0.0";
    };

    cni = {
      provider = "calico";
      calico = {
        vxlanMode = "Never";
        ipAutodetectionMethod = "first-found";
      };
    };
  };
}