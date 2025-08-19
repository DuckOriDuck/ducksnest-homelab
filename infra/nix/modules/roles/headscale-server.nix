{ config, pkgs, lib, ... }:

let
  fqdn = "headscale.example.com";   # ← 실제 도메인
  dataDir = "/var/lib/headscale";
in {
  environment.systemPackages = with pkgs; [ headscale sqlite caddy jq ];

  # 방화벽
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 8080 ];     # 80/443: ACME/HTTPS(리버스 프록시), 8080: headscale API
    allowedUDPPorts = [ 3478 ];            # STUN
    # Tailscale 관리용으로 tailscale0 인터페이스에서 Node Exporter 접근 허용 (옵션)
    interfaces.tailscale0.allowedTCPPorts = [ 9100 ];
  };

  # Caddy로 TLS/ACME 처리(권장) → headscale의 HTTP를 프록시
  services.caddy = {
    enable = true;
    globalConfig = ''
      auto_https disable_redirects
    '';
    virtualHosts."${fqdn}".extraConfig = ''
      encode gzip
      tls {
        issuer acme
      }
      reverse_proxy 127.0.0.1:8080
    '';
  };

  # Headscale
  services.headscale = {
    enable = true;
    settings = {
      server_url = "https://${fqdn}";   # tailscale client가 접속할 URL
      listen_addr = "127.0.0.1:8080";  # Caddy 뒤에 숨김(직접 TLS 대신 프록시로 종단)
      ip_prefixes = [ "100.64.0.0/10" ];
      disable_check_updates = true;

      # Database configuration (new format)
      database = {
        type = "sqlite3";
        sqlite = {
          path = "${dataDir}/db.sqlite";
        };
      };

      # DNS configuration (new format)
      dns = {
        override_local_dns = true;
        magic_dns = true;                 # tailscale MagicDNS
        base_domain = "tail.home";        # tailnet 내부 도메인 (예시)
      };

      # 인증/키 발급 정책
      # CLI에서 preauth key 발급: `headscale -n default preauthkeys create --reusable=false --ephemeral=false --expiration 24h`
      log = {
        format = "text";
        level = "info";
      };

      # 공개 DERP 사용 (기본). 자가 호스트 DERP가 필요할 때만 server.enabled = true
      derp = {
        server = {
          enabled = false;
          region_id = 999;
          region_code = "headscale";
          region_name = "Headscale Embedded DERP";
          stun_listen_addr = "0.0.0.0:3478";
        };
        urls = [ ];   # 공개 DERP만 사용 시 비움
      };
    };
  };

  users.users.headscale = {
    isSystemUser = true;
    group = "headscale";
    home = dataDir;
    createHome = true;
  };
  users.groups.headscale = {};

  systemd.services.headscale = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "headscale";
      Group = "headscale";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ dataDir ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Node exporter (옵션)
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" "filesystem" "netdev" "meminfo" "cpu" "loadavg" ];
  };
}
