{ config, pkgs, ... }:

{
  # Jenkins and Headscale server configuration
  
  # Network configuration
  networking = {
    firewall = {
      allowedTCPPorts = [
        22     # SSH
        8080   # Jenkins
        8090   # Jenkins agent
        80     # HTTP (nginx proxy)
        443    # HTTPS (nginx proxy)
        8081   # Headscale
        41641  # Tailscale/Headscale coordination
      ];
      allowedUDPPorts = [
        41641  # Tailscale/Headscale
      ];
    };
  };

  # System packages for Jenkins and Headscale
  environment.systemPackages = with pkgs; [
    # Jenkins and CI/CD tools
    jenkins
    git
    docker
    docker-compose
    
    # Build tools
    maven
    gradle
    nodejs
    python3
    
    # Infrastructure tools
    terraform
    ansible
    kubectl
    kubernetes-helm
    
    # Networking tools
    nginx
    certbot
    
    # Monitoring
    node_exporter
    
    # Database
    postgresql
  ];

  # Services configuration
  services = {
    # Jenkins CI/CD server
    jenkins = {
      enable = true;
      port = 8080;
      listenAddress = "127.0.0.1";  # Behind nginx proxy
      
      # Java options for Jenkins
      extraJavaOptions = [
        "-Xmx2g"
        "-Xms1g"
        "-Djava.awt.headless=true"
        "-Djenkins.install.runSetupWizard=false"
      ];
      
      # Additional packages available to Jenkins
      packages = with pkgs; [
        git
        docker
        nodejs
        python3
        maven
        terraform
        kubectl
      ];
    };


    # PostgreSQL for Jenkins and Headscale
    postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
      enableTCPIP = true;
      
      ensureDatabases = [ "jenkins" ];
      ensureUsers = [
        {
          name = "jenkins";
          ensurePermissions = {
            "DATABASE jenkins" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # Nginx reverse proxy
    nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      
      virtualHosts = {
        "jenkins.homelab.local" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8080";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_redirect http:// https://;
              proxy_max_body_size 50m;
            '';
          };
        };
        
      };
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
    # Docker configuration for Jenkins agents
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
  
  # Environment variables
  environment.variables = {
    JENKINS_HOME = "/var/lib/jenkins";
  };

  # Systemd services and configuration
  systemd.services = {
  };

  # Security configuration
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  # User configuration for Jenkins
  users.users.jenkins = {
    extraGroups = [ "docker" ];
  };
}