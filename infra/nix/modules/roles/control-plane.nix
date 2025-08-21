{ config, pkgs, ... }:

{
  # Control plane configuration for Kubernetes cluster
  
  # Enable container runtime
  virtualisation = {
    cri-o = {
      enable = true;
    };
  };

  # Network configuration for control plane
  networking = {
    firewall = {
      allowedTCPPorts = [
        22     # SSH
        6443   # Kubernetes API server
        10250  # kubelet API
        10251  # kube-scheduler
        10252  # kube-controller-manager
        10255  # kubelet read-only port
        8472   # Flannel VXLAN
        9090   # Prometheus
      ];
      allowedUDPPorts = [
        8472   # Flannel VXLAN
      ];
    };
  };

  # System packages for control plane
  environment.systemPackages = with pkgs; [
    # Container tools
    cri-o
    cri-tools
    
    # Kubernetes tools
    kubernetes
    kubectl
    kubernetes-helm
    kustomize
    k9s
    
    
    # Network tools
    flannel
    
    # Monitoring and observability
    prometheus
    prometheus-node-exporter
    
    # GitOps tools
    git

    # extra
    fastfetchMinimal
  ];

  # Services for control plane
  services = {
    # Kubernetes API server (configured via kubeadm/k3s)
    

    # Prometheus monitoring
    prometheus = {
      enable = true;
      port = 9090;
      listenAddress = "0.0.0.0";
      
      scrapeConfigs = [
        {
          job_name = "kubernetes-nodes";
          kubernetes_sd_configs = [{
            role = "node";
          }];
          relabel_configs = [
            {
              source_labels = ["__address__"];
              regex = "(.+):(.+)";
              target_label = "__address__";
              replacement = "\${1}:9100";
            }
          ];
        }
        {
          job_name = "kubernetes-pods";
          kubernetes_sd_configs = [{
            role = "pod";
          }];
        }
        {
          job_name = "prometheus";
          static_configs = [{
            targets = [ "localhost:9090" ];
          }];
        }
      ];
    };

    # Node exporter for monitoring
    prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "filesystem"
        "netdev"
        "meminfo"
        "cpu"
        "loadavg"
      ];
    };


  };

  # System tuning for Kubernetes
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
  };

  # Load required kernel modules
  boot.kernelModules = [ "br_netfilter" "overlay" ];

  # Environment variables for Kubernetes
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
  };
}