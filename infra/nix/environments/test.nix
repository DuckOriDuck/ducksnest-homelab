{ ... }:

{
  cluster = {
    name = "ducksnest-k8s-test";
    environment = "test";
    domain = "cluster.local";

    network = {
      podCIDR = "10.244.0.0/16";
      serviceCIDR = "10.0.0.0/16";
      nodeNetwork = "10.100.0.0/24";
      dnsServiceIP = "10.0.0.10";
      apiServerIP = "10.0.0.1";
    };

    controlPlane = {
      hostname = "ducksnest-test-controlplane";
      ipAddress = "10.100.0.2";
      apiServerPort = 6443;
      bindAddress = "0.0.0.0";
    };

    workerNodes = [
      {
        hostname = "ducksnest-test-worker-node";
        ipAddress = "10.100.0.3";
      }
    ];

    cni = {
      provider = "calico";
      calico = {
        vxlanEnabled = true;
        ipAutodetectionMethod = "first-found";
      };
    };
  };
}