{ config, pkgs, commonPackages, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/roles/control-plane.nix
  ];

  # Hostname
  networking.hostName = "ducksnest-controlplane";

  # AWS EC2 specific configuration
  ec2.hvm = true;

  # System packages specific to control plane
  environment.systemPackages = commonPackages ++ (with pkgs; [
    # ArgoCD
    argocd
    
    # Additional control plane tools
    etcdctl
    kubernetes-helm
    
    # AWS CLI
    awscli2
  ]);

  # Control plane specific environment variables
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    HOMELAB_ROLE = "control-plane";
    HOMELAB_ENV = "production";
  };

  # Control plane specific services
  services = {
    # Override Grafana settings for control plane
    grafana.settings.server.domain = "grafana.homelab.ducksnest.com";
    
    # K3s control plane
    k3s = {
      enable = true;
      role = "server";
      extraFlags = [
        "--disable=traefik"  # We'll use nginx ingress
        "--disable=servicelb"
        "--write-kubeconfig-mode=644"
        "--cluster-init"
        "--disable-cloud-controller"
      ];
    };

    # Time synchronization
    timesyncd = {
      enable = true;
      servers = [ "time.google.com" "time.cloudflare.com" ];
    };
  };

  # Systemd services for cluster initialization
  systemd.services = {
    # ArgoCD installation
    argocd-install = {
      description = "Install ArgoCD";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "argocd-install" ''
          #!${pkgs.bash}/bin/bash
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
          
          # Wait for K3s to be ready
          while ! ${pkgs.kubectl}/bin/kubectl get nodes; do
            sleep 5
          done
          
          # Install ArgoCD
          ${pkgs.kubectl}/bin/kubectl create namespace argocd || true
          ${pkgs.kubectl}/bin/kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
          
          # Patch ArgoCD server for insecure mode
          ${pkgs.kubectl}/bin/kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
          ${pkgs.kubectl}/bin/kubectl rollout restart deployment argocd-server -n argocd
        '';
      };
    };
  };

  # This value determines the NixOS release
  system.stateVersion = "23.11";
}