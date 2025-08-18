{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/boot/boot-uefi.nix
    ../../modules/roles/jenkins.nix
    ../../modules/roles/headscale-server.nix
  ];

  # Hostname
  networking.hostName = "ducksnest-jenkins";

  # AWS EC2 specific configuration
  ec2.hvm = true;

  # System packages specific to Jenkins server
  environment.systemPackages = with pkgs; [
    # Additional CI/CD tools
    docker-compose
    terraform
    ansible
    
    # AWS CLI
    awscli2
    
    # Monitoring tools
    prometheus
    grafana
  ];

  # Jenkins specific environment variables
  environment.variables = {
    JENKINS_HOME = "/var/lib/jenkins";
    HEADSCALE_CONFIG = "/etc/headscale/config.yaml";
    HOMELAB_ROLE = "jenkins-headscale";
    HOMELAB_ENV = "production";
  };

  # Additional service configurations
  services = {
    # Prometheus for Jenkins monitoring
    prometheus = {
      enable = true;
      port = 9091;  # Different port to avoid conflicts
      listenAddress = "127.0.0.1";
      
      scrapeConfigs = [
        {
          job_name = "jenkins";
          static_configs = [{
            targets = [ "localhost:8080" ];
          }];
          metrics_path = "/prometheus";
        }
        {
          job_name = "node-exporter";
          static_configs = [{
            targets = [ "localhost:9100" ];
          }];
        }
        {
          job_name = "headscale";
          static_configs = [{
            targets = [ "localhost:9090" ];  # Headscale metrics
          }];
        }
      ];
    };

    # Time synchronization
    timesyncd = {
      enable = true;
      servers = [ "time.google.com" "time.cloudflare.com" ];
    };
  };

  # Jenkins shell aliases
  environment.shellAliases = {
    # Jenkins management
    jenkins-logs = "journalctl -u jenkins -f";
    jenkins-restart = "systemctl restart jenkins";
    
    # Headscale management
    headscale-logs = "journalctl -u headscale -f";
    headscale-users = "headscale users list";
    headscale-nodes = "headscale nodes list";
    
    # Docker shortcuts
    d = "docker";
    dc = "docker-compose";
    dps = "docker ps";
    
    # System monitoring
    htop = "btop";
    ports = "ss -tulpn";
  };

  # This value determines the NixOS release
  system.stateVersion = "25.05";
}