{ config, pkgs, lib, ... }:

let
  # 환경변수 파일 경로: sops/agenix로 관리 권장
  envFile = "/run/secrets/tailscale.env";   # TS_AUTHKEY=tskey-xxxx
  loginServer = "https://headscale.example.com";
in {
  environment.systemPackages = with pkgs; [ tailscale ];

  # 방화벽: tailscale 포트 자동처리 + 내부에서 node-exporter 등 tailscale0로만 허용 가능
  networking.firewall.enable = true;
  # 예시: tailscale0 인터페이스에서만 node-exporter 허용
  # networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ];

  # 라우팅 기능: 제어 트래픽 위주이면 both 필요 없음. 필요 시 "both"
  services.tailscale = {
    enable = true;
  };

  # 비부팅 시 자동 연결
  systemd.services.tailscaled.wantedBy = lib.mkForce [ "multi-user.target" ];

  # 시크릿 주입(예시: 임시 파일. 실제론 sops/agenix로 배포)
  systemd.tmpfiles.rules = [
    "f ${envFile} 0600 root root -"
  ];
  # 데모용: nix build 시 넣지 말고, 배포 단계에서 안전하게 생성하세요.
  # environment.etc."secrets/tailscale.env".text = "TS_AUTHKEY=tskey-xxxxxxxx";

  # (선택) kubeadm/kubelet과의 고정화: tailscale0 IP로 node-ip 지정
  # CP/Worker 각각의 host 모듈에서 아래처럼 오버레이:
  # services.kubernetes.kubelet.extraArgs = {
  #   "node-ip" = "<tailscale0-ip>";
  # };
}
