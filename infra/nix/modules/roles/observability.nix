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
  };

  config = mkIf cfg.enable {
    # Required packages for observability
    environment.systemPackages = with pkgs; [
      prometheus
      prometheus-node-exporter
    ] ++ optionals cfg.grafana.enable [
      grafana
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

    # Firewall configuration
    networking.firewall = mkIf cfg.enable {
      allowedTCPPorts = 
        (optional cfg.prometheus.enable cfg.prometheus.port) ++
        (optional cfg.nodeExporter.enable cfg.nodeExporter.port) ++
        (optional cfg.grafana.enable cfg.grafana.port);
    };
  };
}