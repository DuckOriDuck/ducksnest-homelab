{ config, pkgs, ... }:

{
  # Jenkins server configuration
  
  # Network configuration
  networking = {
    firewall = {
      allowedTCPPorts = [
        22     # SSH
        8080   # Jenkins
        8090   # Jenkins agent
      ];
    };
  };

  # System packages for Jenkins
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
    
    # Monitoring
    node_exporter
  ];

  # Services configuration
  services = {
    # Jenkins CI/CD server
    jenkins = {
      enable = true;
      port = 8080;
      listenAddress = "0.0.0.0";
      
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