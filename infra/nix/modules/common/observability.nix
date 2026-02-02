{ config, lib, pkgs, ... }:

with lib;

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    listenAddress = "0.0.0.0";
    enabledCollectors = [
      "systemd"
      "diskstats"
      "processes"
      "tcpstat"
      "interrupts"
      "softirqs"
    ];
  };
}