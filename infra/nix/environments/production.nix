{ ... }:

{
  cluster = {
    name = "ducksnest-k8s";
    environment = "production";
    domain = "cluster.local";

    network = {
      podCIDR = "10.244.0.0/16";
      serviceCIDR = "10.0.0.0/16";
      nodeNetwork = "192.168.1.0/24";  # Production network
      dnsServiceIP = "10.0.0.10";
      apiServerIP = "10.0.0.1";
    };

    controlPlane = {
      hostname = "ducksnest-controlplane";
      ipAddress = "192.168.1.10";  # Production IP
      apiServerPort = 6443;
      bindAddress = "0.0.0.0";
    };

    workerNodes = [
      {
        hostname = "ducksnest-worker-1";
        ipAddress = "192.168.1.11";
      }
      {
        hostname = "ducksnest-worker-2";
        ipAddress = "192.168.1.12";
      }
      {
        hostname = "ducksnest-worker-3";
        ipAddress = "192.168.1.13";
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