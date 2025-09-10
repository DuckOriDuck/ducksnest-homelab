#!/bin/bash
set -euo pipefail

# DucksNest Homelab 배포 스크립트
# Ubuntu 24.04 기반 AWS EC2 인스턴스에 Jenkins/Headscale + Kubernetes Control Plane 배포

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/infra/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/infra/ansible"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# 도움말
show_help() {
    cat << EOF
DucksNest Homelab 배포 스크립트

사용법: $0 [COMMAND] [OPTIONS]

COMMANDS:
    plan        Terraform plan 실행
    deploy      전체 인프라 배포 (Terraform + Ansible)
    destroy     인프라 제거
    ansible     Ansible만 실행 (인프라가 이미 존재하는 경우)
    status      현재 상태 확인
    help        이 도움말 표시

OPTIONS:
    --dry-run   실제 적용하지 않고 계획만 표시
    --force     확인 없이 강제 실행
    --skip-terraform  Terraform 단계 건너뛰기
    --skip-ansible    Ansible 단계 건너뛰기

예시:
    $0 plan                    # Terraform 계획 확인
    $0 deploy                  # 전체 인프라 배포
    $0 ansible --dry-run       # Ansible 설정 확인
    $0 destroy --force         # 인프라 강제 제거

필요한 환경 변수:
    AWS_REGION              # AWS 리전 (기본값: ap-northeast-2)
    AWS_ACCESS_KEY_ID       # AWS 액세스 키
    AWS_SECRET_ACCESS_KEY   # AWS 시크릿 키
    TF_VAR_key_name         # EC2 키페어 이름

EOF
}

# 환경 변수 확인
check_env() {
    log "환경 설정 확인 중..."
    
    # AWS 자격증명 확인
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        error "AWS 자격증명이 설정되지 않았습니다. AWS_ACCESS_KEY_ID와 AWS_SECRET_ACCESS_KEY를 설정하세요."
    fi
    
    # 기본 AWS 리전 설정
    export AWS_REGION="${AWS_REGION:-ap-northeast-2}"
    
    # EC2 키페어 확인
    if [[ -z "${TF_VAR_key_name:-}" ]]; then
        warn "TF_VAR_key_name이 설정되지 않았습니다. 기본값 'ducksnest-key'를 사용합니다."
        export TF_VAR_key_name="ducksnest-key"
    fi
    
    # SSH 키 파일 확인
    SSH_KEY_PATH="$HOME/.ssh/${TF_VAR_key_name}.pem"
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        warn "SSH 키 파일을 찾을 수 없습니다: $SSH_KEY_PATH"
        warn "AWS 콘솔에서 키페어를 다운로드하고 올바른 위치에 배치하세요."
    fi
    
    log "환경 설정 확인 완료"
}

# 필수 도구 설치 확인
check_tools() {
    log "필수 도구 확인 중..."
    
    local tools=("terraform" "ansible" "jq" "aws")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "다음 도구들이 설치되지 않았습니다: ${missing_tools[*]}"
    fi
    
    log "필수 도구 확인 완료"
}

# Terraform 계획
terraform_plan() {
    log "Terraform 계획 생성 중..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    terraform plan -out=tfplan
    
    log "Terraform 계획이 생성되었습니다. tfplan 파일을 확인하세요."
}

# Terraform 적용
terraform_apply() {
    local force=${1:-false}
    
    log "Terraform 인프라 배포 중..."
    cd "$TERRAFORM_DIR"
    
    terraform init
    
    if [[ "$force" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    
    # 출력값 저장
    terraform output -json > outputs.json
    
    log "Terraform 배포 완료"
}

# Terraform 제거
terraform_destroy() {
    local force=${1:-false}
    
    warn "인프라를 제거하려고 합니다. 이 작업은 되돌릴 수 없습니다!"
    
    if [[ "$force" != "true" ]]; then
        read -p "계속하시겠습니까? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "작업이 취소되었습니다."
            return 0
        fi
    fi
    
    log "Terraform 인프라 제거 중..."
    cd "$TERRAFORM_DIR"
    
    if [[ "$force" == "true" ]]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
    
    log "인프라 제거 완료"
}

# Ansible 인벤토리 업데이트
update_ansible_inventory() {
    log "Ansible 인벤토리 업데이트 중..."
    
    if [[ ! -f "$TERRAFORM_DIR/outputs.json" ]]; then
        error "Terraform 출력 파일을 찾을 수 없습니다. 먼저 Terraform을 실행하세요."
    fi
    
    local outputs=$(cat "$TERRAFORM_DIR/outputs.json")
    local jenkins_ip=$(echo "$outputs" | jq -r '.jenkins_headscale_public_ip.value')
    local k8s_ip=$(echo "$outputs" | jq -r '.k8s_control_plane_public_ip.value')
    
    # 동적 인벤토리 생성
    cat > "$ANSIBLE_DIR/inventory/dynamic.yml" << EOF
---
all:
  vars:
    jenkins_public_ip: "$jenkins_ip"
    jenkins_private_ip: "$(echo "$outputs" | jq -r '.jenkins_headscale_private_ip.value')"
    k8s_cp_public_ip: "$k8s_ip"
    k8s_cp_private_ip: "$(echo "$outputs" | jq -r '.k8s_control_plane_private_ip.value')"
EOF
    
    log "Ansible 인벤토리 업데이트 완료"
    log "Jenkins: $jenkins_ip, Kubernetes: $k8s_ip"
}

# Ansible 실행
run_ansible() {
    local dry_run=${1:-false}
    
    log "Ansible 플레이북 실행 중..."
    cd "$ANSIBLE_DIR"
    
    # 인벤토리 업데이트
    update_ansible_inventory
    
    local ansible_args=""
    if [[ "$dry_run" == "true" ]]; then
        ansible_args="--check --diff"
        log "DRY RUN 모드로 실행합니다."
    fi
    
    # Vault 패스워드 파일 확인
    if [[ ! -f ".vault_pass" ]]; then
        warn "Vault 패스워드 파일이 없습니다. 암호화된 변수를 사용할 수 없습니다."
        warn "echo 'your_vault_password' > .vault_pass 명령으로 생성하세요."
    fi
    
    ansible-playbook -i inventory/hosts.yml -i inventory/dynamic.yml site.yml $ansible_args
    
    log "Ansible 실행 완료"
}

# 상태 확인
check_status() {
    log "인프라 상태 확인 중..."
    
    # Terraform 상태 확인
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        log "Terraform 상태:"
        cd "$TERRAFORM_DIR"
        terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_instance") | "\(.values.tags.Name): \(.values.public_ip) (\(.values.instance_state))"'
    else
        warn "Terraform 상태 파일을 찾을 수 없습니다."
    fi
    
    # 인스턴스 연결 테스트
    if [[ -f "$TERRAFORM_DIR/outputs.json" ]]; then
        local outputs=$(cat "$TERRAFORM_DIR/outputs.json")
        local jenkins_ip=$(echo "$outputs" | jq -r '.jenkins_headscale_public_ip.value')
        local k8s_ip=$(echo "$outputs" | jq -r '.k8s_control_plane_public_ip.value')
        
        log "인스턴스 연결 테스트:"
        
        # Jenkins/Headscale 서버 테스트
        if timeout 5 nc -z "$jenkins_ip" 22 2>/dev/null; then
            echo -e "  ✅ Jenkins/Headscale ($jenkins_ip): SSH 연결 가능"
        else
            echo -e "  ❌ Jenkins/Headscale ($jenkins_ip): SSH 연결 실패"
        fi
        
        # Kubernetes Control Plane 테스트
        if timeout 5 nc -z "$k8s_ip" 22 2>/dev/null; then
            echo -e "  ✅ Kubernetes CP ($k8s_ip): SSH 연결 가능"
        else
            echo -e "  ❌ Kubernetes CP ($k8s_ip): SSH 연결 실패"
        fi
    fi
}

# 메인 함수
main() {
    local command=${1:-help}
    local dry_run=false
    local force=false
    local skip_terraform=false
    local skip_ansible=false
    
    # 옵션 파싱
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --skip-terraform)
                skip_terraform=true
                shift
                ;;
            --skip-ansible)
                skip_ansible=true
                shift
                ;;
            *)
                warn "알 수 없는 옵션: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 명령어 실행
    case $command in
        help|--help|-h)
            show_help
            ;;
        plan)
            check_env
            check_tools
            terraform_plan
            ;;
        deploy)
            check_env
            check_tools
            
            if [[ "$skip_terraform" != "true" ]]; then
                terraform_apply "$force"
            fi
            
            if [[ "$skip_ansible" != "true" ]]; then
                run_ansible "$dry_run"
            fi
            
            log "🎉 배포 완료!"
            check_status
            ;;
        destroy)
            check_env
            check_tools
            terraform_destroy "$force"
            ;;
        ansible)
            check_env
            check_tools
            run_ansible "$dry_run"
            ;;
        status)
            check_status
            ;;
        *)
            error "알 수 없는 명령어: $command. 'help'로 사용법을 확인하세요."
            ;;
    esac
}

# 스크립트 실행
main "$@"