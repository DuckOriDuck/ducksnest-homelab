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
    headscale
    tailscale
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

    # Headscale coordination server
    headscale = {
      enable = true;
      address = "0.0.0.0";
      port = 8081;
      
      settings = {
        server_url = "https://headscale.homelab.local";
        listen_addr = "0.0.0.0:8081";
        metrics_listen_addr = "127.0.0.1:9090";
        
        # Database configuration
        database_type = "postgres";
        database_url = "postgres://headscale:headscale@localhost/headscale?sslmode=disable";
        
        # DERP configuration
        derp = {
          server = {
            enabled = true;
            region_id = 999;
            region_code = "homelab";
            region_name = "Homelab";
            stun_listen_addr = "0.0.0.0:3478";
          };
          
          urls = [
            "https://controlplane.tailscale.com/derpmap/default"
          ];
          
          auto_update_enabled = true;
          update_frequency = "24h";
        };
        
        # DNS configuration
        dns_config = {
          base_domain = "homelab.local";
          magic_dns = true;
          domains = [ "homelab.local" ];
          nameservers = [ "1.1.1.1" "8.8.8.8" ];
        };
        
        # Log configuration
        log_level = "info";
        
        # ACL policy (basic setup)
        acl_policy_path = "/var/lib/headscale/policy.json";
      };
    };

    # PostgreSQL for Jenkins and Headscale
    postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
      enableTCPIP = true;
      
      ensureDatabases = [ "jenkins" "headscale" ];
      ensureUsers = [
        {
          name = "jenkins";
          ensurePermissions = {
            "DATABASE jenkins" = "ALL PRIVILEGES";
          };
        }
        {
          name = "headscale";
          ensurePermissions = {
            "DATABASE headscale" = "ALL PRIVILEGES";
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
        
        "headscale.homelab.local" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8081";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
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

    # SSH server with hardened configuration
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        AllowUsers = [ "duck" ];
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };
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

  # Environment variables
  environment.variables = {
    JENKINS_HOME = "/var/lib/jenkins";
    HEADSCALE_CONFIG = "/etc/headscale/config.yaml";
  };

  # Systemd services and configuration
  systemd.services = {
    # Headscale ACL policy setup
    headscale-setup = {
      description = "Setup Headscale ACL policy";
      after = [ "headscale.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "headscale-setup" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p /var/lib/headscale
          
          # Create basic ACL policy if it doesn't exist
          if [ ! -f /var/lib/headscale/policy.json ]; then
            cat > /var/lib/headscale/policy.json << 'EOF'
          {
            "hosts": {
              "homelab": "100.64.0.0/10"
            },
            "acls": [
              {
                "action": "accept",
                "src": ["homelab"],
                "dst": ["homelab:*"]
              }
            ]
          }
          EOF
          fi
          
          chown headscale:headscale /var/lib/headscale/policy.json
        '';
      };
    };
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