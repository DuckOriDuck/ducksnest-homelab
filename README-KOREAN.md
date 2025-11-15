# ducksnest-homelab
<img width="512" height="512" alt="ducksnest" src="https://github.com/user-attachments/assets/7ee273a7-fb4c-4ec3-96c5-fb8ebc156646" />

## 개요
- **[English Version](/README.md)**
- **[인프라 개요](infra/README-KOREAN.md)** – Terraform & NixOS 인프라 문서  
- **[NixOS 아키텍처](infra/nix/README.md)** – NixOS 구성 및 Kubernetes 설정 문서

---

- [소개](#소개)
- [프로젝트 목적](#프로젝트-목적)
  - [최종 목표](#최종-목표)
- [기술 스택](#기술-스택)
  - [하드웨어](#하드웨어)
    - [온프레미스](#온프레미스)
    - [클라우드](#클라우드)
  - [소프트웨어](#소프트웨어)
- [네트워크 설계](#네트워크-설계)
  - [인프라 구성 요약 (EC2가 Control Plane일 때)](#인프라-구성-요약-ec2가-control-plane일-때)
  - [네트워크 & CIDR 맵](#네트워크--cidr-맵)
- [현재까지의 진행 상황](#현재까지의-진행-상황)
  - [Nix 방식의 Kubernetes](#nix-방식의-kubernetes)
  - [EC2 프로비저닝 문제 해결](#ec2-프로비저닝-문제-해결)
  - [Calico 설치 문제 해결](#calico-설치-문제-해결)
  - [CA/TLS 관리 문제 해결](#catls-관리-문제-해결)
- [현재 진행중인 이슈](#현재-진행중인-이슈)

## 소개
Ducksnest는 **온프레미스 NixOS 워커 노드 + EC2 컨트롤 플레인**으로 구성된 하이브리드 클라우드 홈랩입니다.  
가능한 모든 구성 요소를 **선언형(Declarative)** 으로 관리하는 것을 목표로 하고 있으며, NixOS의 재현성 기반 인프라 설계 철학을 적극 활용하고 있습니다.

이 클러스터 위에서 개인 블로그 또는 포트폴리오 서비스를 배포할 예정입니다.

---

## 프로젝트 목적

1. 집에서 남는 컴퓨팅 리소스를 최대한 활용하기 위해
2. Nix와 Kubernetes를 실전 수준으로 깊게 학습하기 위해
3. 재미를 위해 — *Homo Ludens*: “인간은 놀기 위해 존재한다.”  
   이 프로젝트를 통해 학습과 실험 그 자체를 즐겁고 창의적인 경험으로 만들고자 합니다.

## 최종 목표
최종적으로는 완전한 배포 자동화 파이프라인, 고가용성을 갖춘 데이터베이스, 그리고 로컬 머쉰이 다운되면 EC2에서 자동으로 대체 워커 노드를 프로비저닝하는 DR 환경까지 구축하는 것이 목표입니다. 또한 로깅이나 데이터베이스 스냅샷을 S3에 저장하는 등, 클라우드와 온프레미스를 조합한 하이브리드 클러스터의 장점을 최대한 활용한 저만의 홈랩을 완성하고자 합니다.
Control Plane이 EC2에 자리 잡고 있기 때문에 시도해볼 수 있는 확장 방향도 많아 앞으로의 구축 과정이 기대됩니다.

#### 고가용적인 CP에 대해서
쿠버네티스를 선택한 이유는 여러 노드를 중앙에서 일관성 있게 관리할 수 있고, 다양한 자동화 애드온과의 호환성이 뛰어나기 때문입니다. 다만 제 환경은 규모가 크지 않고 실제 사용 인원도 많지 않기 때문에, 지금 단계에서 고가용성 Control Plane을 구성하는 것은 과도한 비용과 운영 부담이라고 판단했습니다. 그래서 현재는 단일 Control Plane으로 충분하며, 고가용성 구성은 아직 고려하고 있지 않습니다.

하지만 추후 여유가 생기면 온프레미스 장비를 추가해 Control Plane과 Worker Node 모두를 확장할 의향이 있습니다. 지금은 단일 Control Plane 기반으로 구축을 진행하되, 구조 자체는 언제든 확장할 수 있도록 설계해 두려 합니다.

## 기술 스택

### 하드웨어

#### 온프레미스

| Alias | CPU | Memory | Disk | GPU |
|-------|------|---------|------|------|
| **firebat** | Intel N100 (4) @ 3.40 GHz | 15.4 GiB | 467.4 GiB ext4 | Intel UHD Graphics |
| **ultra** | Intel i5-8250U (8) @ 3.40 GHz | 15.5 GiB | 914.8 GiB ext4 | NVIDIA GTX 1050 Mobile / Intel UHD 620 |
| **old** | Intel i3-M 330 (4) @ 2.13 GHz | 1.9 GiB | 288.6 GiB ext4 | NVIDIA GeForce 310M |

#### 클라우드

| Alias | Instance Type | vCPU | Memory |
|--------|----------------|------|----------|
| **control-plane (EC2)** | t3.medium | 2 | 4 GiB |

---

### 소프트웨어

| Category | Technology | 채택 이유 |
|----------|------------|-----------|
| **OS** | NixOS | ultra 노트북이 systemd-boot만 지원하여 선택지가 제한(Arch/NixOS/FreeBSD)이었고, 그중 **NixOS으 리눅스 패키지 종속성, 시스템 전체 선언형 관리 모델이** 서버 관리에 제일 적합하다고 판단했습니다. |
| **오케스트레이션** | Kubernetes | 여러 대의 온프레미스 워커 노드와 EC2 Control Plane을 하이브리드로 묶기 위해 **노드 상태 관리·Pod 스케줄링·자동 복구·선언형 설정** 등이 필수였고, 그중 Kubernetes가 가장 안정적이었습니다. Helm/ArgoCD와 결합하면 **GitOps 기반 운영 자동화**도 쉽게 구현할 수 있다는 점이 선택의 핵심 이유였습니다. |
| **VPN** | Tailscale | 서로 다른 네트워크 대역(로컬 → WAN → AWS)을 연결해야 했기 때문에 NAT Traversal과 Mesh 방식의 동적 라우팅이 중요했습니다. Tailscale은 **Zero-Config 수준의 설정**, 강력한 NAT 우회 성능, 안정성, ACL 기반 정책 제어, 그리고 추후 **Headscale로 자체 VPN 서버 구축까지 확장 가능**한 점 때문에 채택했습니다. GitHub Actions에서 한 줄로 노드를 Tailnet에 붙일 수 있다는 점도 큰 장점입니다. |
| **CNI** | Calico | 온프레미스 노드끼리는 **로컬 LAN 라우팅**, EC2와는 **Tailscale L3 라우팅**, 이 두 구조를 동시에 지원하려면 유연한 CNI가 필요했습니다. Calico는 **VXLAN / BGP / CrossSubnet 등 다양한 encapsulation 전략**을 선택적으로 구성할 수 있고, 네트워크 정책 기능도 강력해 하이브리드 환경에 가장 적합했습니다. Flannel은 기능이 제한적이었고, Cilium(eBPF)도 좋은 옵션이었지만, 이번 프로젝트 규모에는 과하다고 판단했습니다. |
| **IaC** | NixOS Modules + Terraform | NixOS 환경에서 시스템 패키지·서비스·네트워크·Kubernetes 자체를 모두 **하나의 선언형 구성으로 관리**해 수 있어 인프라 재현성을 극대화했습니다. 여기에 Terraform을 결합해 AWS EC2, S3, IAM, Route53 등 **클라우드 리소스를 모두 코드로 만들고 유지**할 수 있어 전체 환경을 완전히 IaC로 통합할 수 있었습니다. IaC중 AWS CloudFormation도 검토했지만 벤더 종속성이 강해 제외했습니다. |
| **CI/CD** | GitHub Actions | S3 기반 Nix Binary Cache에 빌드 결과를 업로드하고, SSH 키/Cert 등을 안전하게 다루기 위한 **GitHub Secrets 및 OIDC 기반 AWS 인증**과의 호환성이 매우 좋았습니다. 또한 리포지토리 중심 개발(GitOps)과 자연스럽게 연결되고, 워크플로우 관리도 타 옵션(jenkins)에 비해 단순해 선택했습니다. |`


---

## 네트워크 설계

<img width="763" height="721" alt="network-design" src="https://github.com/user-attachments/assets/e0c73acf-7678-49ad-bc1a-286b41fc0f09" />

### 인프라 구성 요약 (EC2가 Control Plane일 때)

- **Control Plane:** `EC2`
- **Workers:** `firebat`, `ultra`, `old`
- **라우팅 전략**
  - 로컬 워커 노드끼리는 **Local Network** 기반 L2/L3 통신
  - EC2 ↔ On-prem 워커 노드는 **Tailscale**을 통한 L3 통신
  - **Calico의 Vxlan: cross-subnet 옵션을 사용해 온프레미스 노드끼리는 로컬 네트워크로 통신, CP 컴포넌트와는 tailscale 인터페이스를 통해 통신하도록 설계했습니다.**

### 네트워크 & CIDR 맵

| 항목 | CIDR / 인터페이스 | 설명 |
| --- | --- | --- |
| **Pod CIDR (Calico pool)** | 10.244.0.0/16 | Calico VXLAN 기반 Pod 네트워크 |
| **Service CIDR** | 10.96.0.0/12 | ClusterIP 서비스용 가상 IP |
| **Local LAN** | 192.168.0.0/24 | 동일 물리망에 있는 온프레미스 노드 라우팅 |
| **Tailnet (Tailscale)** | 100.64.0.0/10 | EC2 ↔ On-prem 간 API/Pod 통신 |
| **Node IP Autodetection** | interface=wlan* | tailscale0 제외, 로컬 Wi-Fi 인터페이스를 노드 IP로 자동 감지 |
| **Calico MTU** | 1280 | Tailnet MTU에 맞춰 캡슐화 시 단편화 방지 |

---

## 현재까지의 진행 상황

### Nix 방식의 Kubernetes

모든 Kubernetes 컴포넌트를 NixOS 모듈로 선언형 관리합니다.

부팅 시 다음 항목이 자동으로 부트스트랩 됩니다:
- TLS 인증서 key pair와 CA
- systemd 기반 RBAC/CRD/Calico 컴포넌트 부트스트래핑

### EC2 프로비저닝 문제 해결

- **문제**  
  낮은 사양의 EC2에서 NixOS를 풀 빌드하면 디스크 I/O와 CPU 병목 때문에 **15–20분** 소요되는 문제가 발생했습니다.

- **대안 검토**
  - AMI Baking → 자동화 파이프라인이 너무 복잡해질것을 고려해 기각했습니다.
  - Cachix → 월 €50, 지나치게 비싸 기각했습니다.
  - 임시 고성능 빌드 머신 → 설정이 지나치게 복잡해질 것으로 보여 기각했습니다.
  - **S3 Binary Cache** → 선택  
    - 로컬/CI 빌드 성공 시 S3에 바이너리 캐시 업로드 하고  
    - EC2에서 이를 substitute 옵션으로 레퍼런스해 빠르게 빌드 파일을 다운로드하도록 했습니다.  

- **결과**  
  NixOS 초기 빌드 시간 을 **1분 미만**으로 약**93% 이상 감축**했습니다.  

---

### Calico 설치 문제 해결
- **문제**  
  - NixOS에서는 `/etc`, `/opt` 하위가 Nix 빌드 결과로 매번 자동 생성되는 불변 영역이기 때문에, 런타임에서 파일을 쓰거나 수정하려는 모든 시도가 덮어씌워지거나 거부되어 동작하지 않는다는 특성을 가지고 있습니다.  
  - 이 때문에 Calico의 공식 설치 방식인 Tigera Operator나 Helm chart가 CNI 바이너리를 해당 디렉토리에 배치하려 할 때 충돌이 발생하여 정상적으로 설치가 이루어지지 않았습니다.

- **해결 방안**  
  - **NixPkgs를 통한 Calico CNI 바이너리 배포**  
    - NixOS의 불변 파일시스템 제약을 우회하기 위해 Calico CNI 바이너리를 NixPkgs로 각 노드에서 nixos-rebuild시 설치되게 했습니다.
    - Nix 패키지로 설치되는 바이너리는 `/nix/store` 기반이므로 `/etc`, `/opt` 파일 쓰기 거부 문제를 겪지 않았습니다.
    - Calico는 `calico`와 `calico-ipam` 두 개의 바이너리를 필요로 하지만 NixPkgs에는 배포판에는 `calico`만 존재했기 때문에,  
    설치 과정에서 `calico-ipam` → `calico` 를 바라보는 심볼릭 링크를 생성해 요구사항을 충족했습니다.

  - **Calico 클러스터 컴포넌트 선언형 부트스트래핑**  
    - [Calico the Hard Way](https://docs.tigera.io/calico/latest/getting-started/kubernetes/hardway/overview)를 참고하여 Calico 작동에 필요한 CRD, RBAC, Calico Node DaemonSet 등 Calico 구성 요소의 yaml 파일을 선언하고, Control plane에서 이를 nixos-rebuild시 부트스트래핑하는 nix 모듈을 구현했습니다.
    - 바이너리 위치, CNI config 경로, 클러스터 공통 CA로 서명된 TLS 인증서 등 필요한 부분을 직접 커스텀하여  
    클러스터 구조와 일치하도록 조정했습니다.


- **결과**
  - Helm chart, Tigera Operator 없이 NixOS 부트스트래핑 단계에서 Calico 구성 요소가 자동 배포되도록 구성하여 완전한 선언형 설치 구조를 구현했습니다.
  - `vxlan: CrossSubnet` 옵션을 활용해 온프레미스 노드 간에는 로컬 네트워크로 통신하고, Control Plane과의 연결은 Tailscale 네트워크를 통해 이루어지도록 설계했습니다.

---
### CA/TLS 관리 문제 해결
- **문제**  
  - Kubeadm, Minikube, K3s 같은 툴 없이 **모든 Kubernetes 컴포넌트를 Nix 파일로 직접 선언하여 배포**하는 구조였기 때문에 CA/TLS 인증서를 수동으로 관리해야 했습니다.
  - API Server, Kubelet, Kube-Controller-Manager, Scheduler, Etcd 등 **수십 개에 달하는 TLS 인증서와 설정 파일**들을 일일이 수동 관리해야 하는 부담이 발생했습니다.
  
- **해결 방안**  
  - [NixCon 2025 - Kubernetes on Nix](https://www.youtube.com/watch?v=leR6m2plirs&t=967s), [gitlab: Lukas- K8Nix](https://gitlab.com/luxzeitlos/k8nix)에서 소개된 TLS 관리 방법을 참고하여 자체 자동화 파이프라인 nix 모듈을 구축했습니다.
<img width="1307" height="511" alt="certtoolkit2" src="https://github.com/user-attachments/assets/7c976159-e9d0-413c-917d-271ff3d2d813" />

  - 각 노드마다 **SSH 키 페어(비대칭 키)**를 생성하여:
    - **Public key** → GitHub 리포지토리에 저장  
    - **Private key** → 각 노드의 로컬 NixOS 파일시스템에 저장
  - `nix run certs-recreate` 실행 시:
    1. 새로운 Cluster CA 생성  
    2. API Server, Kubelet, ControllerManager, Scheduler, Etcd 등  **모든 Kubernetes 컴포넌트용 TLS 인증서 생성**
    3. 각 인증서의 **private key를 해당 노드의 SSH public key로 암호화**
    4. 암호화된 TLS 비밀키를 GitHub 리포지토리에 안전하게 업로드

  - 각 노드에서 `nixos-rebuild`를 실행하면:
    1. GitHub에서 암호화된 TLS 파일을 가져옴  
    2. 자신의 SSH private key로 복호화
    3. 복호화된 TLS 인증서를 각 컴포넌트(API server, kubelet 등)에 적용  
    4. 선언형 설정에 의해 자동으로 서비스가 재구성됨

- **결과**
  - 번거로운 CA/TLS 관리 메커니즘을 `nix run certs-recreate`명령어 하나로 해결되도록 했습니다.
  - Worker Node는 이미 Control Plane의 CA로 서명된 kubelet용 TLS 인증서와 API Server 엔드포인트 정보를 가지고 있기 때문에, nixos-rebuild만 실행하면 별도의 조인 과정 없이 자동으로 Control Plane에 연결될 수 있습니다.



자세한 내용은: **[infra/nix/README.md](infra/nix/README.md)**

---

## 현재 진행중인 이슈
- AI로 쓴 rough draft인 **[infra/nix/README.md](infra/nix/README.md)**, **[infra/README.md](infra/README.md)** 수정, 한글화
- 어플리케이션 자동 배포 파이프라인을 위한 ArgoCD 추가
- 관측성 추가, 로그 수집 및 관리 전략 수립
- STS를 활용한 클러스터 내 고가용적인 PostgreSQ DB
- 포트폴리오 웹 애플리케이션 배포
- CF또는 Tailscale 기능을 사용해 엔드포인트 활성화, 클러스터 배포
