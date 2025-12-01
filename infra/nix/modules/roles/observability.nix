{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.observability;
in
{
  options.services.observability = {
    enable = mkEnableOption "observability stack (Prometheus, Grafana, etc.)";

    prometheus = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Prometheus monitoring";
      };

      port = mkOption {
        type = types.port;
        default = 9090;
        description = "Prometheus port";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Prometheus listen address";
      };
    };

    nodeExporter = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Node Exporter";
      };

      port = mkOption {
        type = types.port;
        default = 9100;
        description = "Node Exporter port";
      };
    };

    grafana = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Grafana dashboard";
      };

      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Grafana port";
      };
    };

    promtail = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Promtail log aggregator";
      };

      port = mkOption {
        type = types.port;
        default = 9080;
        description = "Promtail HTTP port";
      };

      lokiUrl = mkOption {
        type = types.str;
        default = "http://loki.observability.svc.cluster.local:3100";
        description = "Loki push endpoint URL";
      };

      extraScrapeConfigs = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = "Additional scrape configs for Promtail";
      };
    };

    clusterName = mkOption {
      type = types.str;
      default = "duck-hybrid";
      description = "Cluster name for observability labels";
    };

    environment = mkOption {
      type = types.str;
      default = "homelab";
      description = "Environment name for observability labels";
    };
  };

  config = mkIf cfg.enable {
    # Required packages for observability
    environment.systemPackages = with pkgs; [
      prometheus
      prometheus-node-exporter
    ] ++ optionals cfg.grafana.enable [
      grafana
    ] ++ optionals cfg.promtail.enable [
      grafana-loki  # Contains promtail binary
    ];

    # Prometheus service
    services.prometheus = mkIf cfg.prometheus.enable {
      enable = true;
      port = cfg.prometheus.port;
      listenAddress = cfg.prometheus.listenAddress;
      
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
              replacement = "\${1}:${toString cfg.nodeExporter.port}";
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
            targets = [ "localhost:${toString cfg.prometheus.port}" ];
          }];
        }
      ];
    };

    # Node Exporter service
    services.prometheus.exporters.node = mkIf cfg.nodeExporter.enable {
      enable = true;
      port = cfg.nodeExporter.port;
      enabledCollectors = [
        "systemd"
        "filesystem"
        "netdev"
        "meminfo"
        "cpu"
        "loadavg"
        "diskstats"
        "processes"
      ];
    };

    # Grafana service
    services.grafana = mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          http_addr = "0.0.0.0";
        };
        security = {
          admin_user = "admin";
          admin_password = "admin"; # Change this in production!
        };
      };
    };

    # Promtail service
    systemd.services.promtail = mkIf cfg.promtail.enable {
      description = "Promtail log aggregator";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "promtail";
        Group = "promtail";
        DynamicUser = true;
        ExecStart = "${pkgs.grafana-loki}/bin/promtail -config.file=/etc/promtail/config.yaml";

        # State directory for positions file
        StateDirectory = "promtail";
        ConfigurationDirectory = "promtail";

        # Environment variables
        Environment = [
          "LOKI_URL=${cfg.promtail.lokiUrl}"
          "NODE_NAME=%H"
          "CLUSTER_NAME=${cfg.clusterName}"
          "ENVIRONMENT=${cfg.environment}"
        ];

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;

        # Need access to logs
        ReadOnlyPaths = [
          "/var/log/journal"
          "/var/log/containers"
        ];

        # Add to systemd-journal group for journal access
        SupplementaryGroups = [ "systemd-journal" ];

        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Promtail configuration file
    environment.etc."promtail/config.yaml" = mkIf cfg.promtail.enable {
      text = ''
        server:
          http_listen_port: ${toString cfg.promtail.port}
          grpc_listen_port: 0

        positions:
          filename: /var/lib/promtail/positions.yaml

        clients:
          - url: ''${LOKI_URL}/loki/api/v1/push

        scrape_configs:
          # Scrape journald logs (systemd journal)
          - job_name: journald
            journal:
              path: /var/log/journal
              max_age: 12h
              labels:
                job: systemd-journal
                node_name: ''${NODE_NAME}
                cluster: ''${CLUSTER_NAME}
                environment: ''${ENVIRONMENT}
            relabel_configs:
              - source_labels: ['__journal__systemd_unit']
                target_label: 'unit'
              - source_labels: ['__journal__hostname']
                target_label: 'hostname'
              - source_labels: ['__journal_priority']
                target_label: 'level'

          # Scrape Kubernetes container logs
          - job_name: kubernetes-pods
            static_configs:
              - targets:
                  - localhost
                labels:
                  job: kubernetes-pods
                  node_name: ''${NODE_NAME}
                  cluster: ''${CLUSTER_NAME}
                  environment: ''${ENVIRONMENT}
                  __path__: /var/log/containers/*.log

            pipeline_stages:
              # Parse container log format
              - regex:
                  expression: '^(?P<timestamp>\S+) (?P<stream>stdout|stderr) (?P<flags>\S+) (?P<log>.*)$'
              - labels:
                  stream:
              - timestamp:
                  source: timestamp
                  format: RFC3339Nano
              - output:
                  source: log

          ${lib.optionalString (cfg.promtail.extraScrapeConfigs != []) ''
          # Additional scrape configs
          ${builtins.toJSON cfg.promtail.extraScrapeConfigs}
          ''}
      '';
    };

    # Create promtail user and group
    users.users.promtail = mkIf cfg.promtail.enable {
      isSystemUser = true;
      group = "promtail";
      extraGroups = [ "systemd-journal" ];
    };
    users.groups.promtail = mkIf cfg.promtail.enable {};

    # Firewall configuration
    networking.firewall = mkIf cfg.enable {
      allowedTCPPorts =
        (optional cfg.prometheus.enable cfg.prometheus.port) ++
        (optional cfg.nodeExporter.enable cfg.nodeExporter.port) ++
        (optional cfg.grafana.enable cfg.grafana.port) ++
        (optional cfg.promtail.enable cfg.promtail.port);
    };
  };
}