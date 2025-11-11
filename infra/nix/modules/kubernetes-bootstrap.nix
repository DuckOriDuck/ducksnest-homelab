{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.kubernetes.bootstrap;

  # Bootstrap task type
  taskType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this bootstrap task";
      };

      description = mkOption {
        type = types.str;
        description = "Description of the bootstrap task";
      };

      script = mkOption {
        type = types.str;
        description = "Path to the bootstrap script";
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Arguments to pass to the script";
      };

      after = mkOption {
        type = types.listOf types.str;
        default = [ "multi-user.target" ];
        description = "systemd units this task should run after";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables for the script";
      };

      wantedBy = mkOption {
        type = types.listOf types.str;
        default = [ "multi-user.target" ];
        description = "systemd units that want this task";
      };

      preStart = mkOption {
        type = types.lines;
        default = "";
        description = "Commands to run before the main script";
      };
    };
  };

  # Generate systemd service for a bootstrap task
  mkBootstrapService = name: task:
    nameValuePair "k8s-bootstrap-${name}" {
      description = task.description;
      wantedBy = task.wantedBy;
      after = task.after;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      } // (optionalAttrs (task.environment != {}) {
        Environment = mapAttrsToList (k: v: "${k}=${v}") task.environment;
      });
      preStart = task.preStart;
      script = ''
        ${pkgs.bash}/bin/bash ${task.script} ${concatStringsSep " " (map escapeShellArg task.args)}
      '';
    };
in
{
  options.kubernetes.bootstrap = {
    enable = mkEnableOption "Kubernetes bootstrap services";

    tasks = mkOption {
      type = types.attrsOf taskType;
      default = {};
      description = ''
        Bootstrap tasks to run. Each task will create a systemd service
        named "k8s-bootstrap-<name>". Tasks are executed as oneshot services
        and can depend on each other using the 'after' option.

        Example:
          kubernetes.bootstrap.tasks.generate-kubeconfig = {
            description = "Generate admin kubeconfig";
            script = "/path/to/generate-kubeconfig.sh";
            args = [ "/etc/kubernetes/admin.conf" "https://api:6443" ];
            after = [ "kube-apiserver.service" ];
            environment = { KUBECONFIG = "/etc/kubernetes/admin.conf"; };
          };
      '';
    };
  };

  config = mkIf cfg.enable {
    # Generate systemd services for all enabled tasks
    systemd.services = mapAttrs' mkBootstrapService
      (filterAttrs (name: task: task.enable) cfg.tasks);
  };
}
