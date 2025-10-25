#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🔨 DucksNest Kubernetes Test VM Builder${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Function to print section headers
section() {
    echo -e "\n${BLUE}→${NC} $1"
}

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "$SCRIPT_DIR/flake.nix" ]; then
    error "Not in infra/nix directory. Please run from there."
    exit 1
fi

# Parse arguments
BUILD_CP=true
BUILD_WN=true
RUN_AFTER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cp-only)
            BUILD_WN=false
            shift
            ;;
        --wn-only)
            BUILD_CP=false
            shift
            ;;
        --run)
            RUN_AFTER=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cp-only     Build only control-plane VM"
            echo "  --wn-only     Build only worker-node VM"
            echo "  --run         Run VMs after building (requires tmux)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build test-controlplane
if [ "$BUILD_CP" = true ]; then
    section "Building test-controlplane VM..."
    if nix build '.#nixosConfigurations.test-controlplane.config.system.build.vm' \
        --out-link result-cp \
        -L 2>&1 | tail -20; then
        success "test-controlplane VM built successfully"
        success "VM script: ./result-cp/bin/run-ducksnest-test-controlplane-vm"
    else
        error "Failed to build test-controlplane VM"
        exit 1
    fi
fi

# Build test-worker-node
if [ "$BUILD_WN" = true ]; then
    section "Building test-worker-node VM..."
    if nix build '.#nixosConfigurations.test-worker-node.config.system.build.vm' \
        --out-link result-wn \
        -L 2>&1 | tail -20; then
        success "test-worker-node VM built successfully"
        success "VM script: ./result-wn/bin/run-ducksnest-test-worker-node-vm"
    else
        error "Failed to build test-worker-node VM"
        exit 1
    fi
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All VMs built successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Show how to run
echo -e "${BLUE}To run the VMs:${NC}"
if [ "$BUILD_CP" = true ]; then
    echo -e "  ${YELLOW}Control Plane:${NC}"
    echo -e "    ./result-cp/bin/run-ducksnest-test-controlplane-vm"
fi
if [ "$BUILD_WN" = true ]; then
    echo -e "  ${YELLOW}Worker Node:${NC}"
    echo -e "    ./result-wn/bin/run-ducksnest-test-worker-node-vm"
fi

# Optional: Run VMs in tmux (headless in tmux panes)
if [ "$RUN_AFTER" = true ]; then
  if ! command -v tmux &>/dev/null; then
    warning "tmux is not installed. Run VMs manually or install tmux."
    exit 0
  fi

  section "Starting VMs inside tmux (headless)..."

  # 새로 시작하기 전 기존 세션 정리
  tmux has-session -t ducksnest-test 2>/dev/null && tmux kill-session -t ducksnest-test || true

  # QEMU를 tmux 창 안에 붙이기 위한 옵션
  VM_EXTRA_ARGS="-nographic -serial mon:stdio"

  # Control Plane 창 생성 + 실행 (작업 디렉토리 고정 + bash -lc)
  tmux new-session -d -s ducksnest-test -n control -c "$SCRIPT_DIR" \
    "bash -lc './result-cp/bin/run-ducksnest-test-controlplane-vm ${VM_EXTRA_ARGS} 2>&1 | tee cp.log; echo; read -n1 -p \"[CP ENDED] Press any key...\"'"

  success "Control Plane VM launched in tmux window 'control'."

  # Worker 창 생성 + 실행(선택)
  if [ "$BUILD_WN" = true ]; then
    tmux new-window -t ducksnest-test -n worker -c "$SCRIPT_DIR" \
      "bash -lc './result-wn/bin/run-ducksnest-test-worker-node-vm ${VM_EXTRA_ARGS} 2>&1 | tee wn.log; echo; read -n1 -p \"[WN ENDED] Press any key...\"'"
    success "Worker Node VM launched in tmux window 'worker'."
  fi

  # 이미 tmux 안이면 attach 대신 switch (중첩 경고 방지)
  if [ -n "${TMUX-}" ]; then
    tmux switch-client -t ducksnest-test
  else
    tmux attach -t ducksnest-test
  fi
fi
