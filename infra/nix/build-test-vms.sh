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

# Optional: Run VMs in tmux
if [ "$RUN_AFTER" = true ]; then
    if ! command -v tmux &> /dev/null; then
        warning "tmux is not installed. Run VMs manually or install tmux."
        exit 0
    fi

    section "Starting VMs in tmux..."

    # Create tmux session
    tmux new-session -d -s ducksnest-test -x 200 -y 50

    if [ "$BUILD_CP" = true ]; then
        tmux new-window -t ducksnest-test -n cp
        tmux send-keys -t ducksnest-test:cp "cd $SCRIPT_DIR && ./result-cp/bin/run-ducksnest-test-controlplane-vm" Enter
        success "Control-plane VM started in tmux window 'cp'"
    fi

    if [ "$BUILD_WN" = true ]; then
        tmux new-window -t ducksnest-test -n wn
        tmux send-keys -t ducksnest-test:wn "cd $SCRIPT_DIR && ./result-wn/bin/run-ducksnest-test-worker-node-vm" Enter
        success "Worker-node VM started in tmux window 'wn'"
    fi

    echo -e "\n${BLUE}Tmux session: ducksnest-test${NC}"
    echo -e "  Attach with: ${YELLOW}tmux attach -t ducksnest-test${NC}"
    echo -e "  Switch windows: ${YELLOW}Ctrl-B + 0/1/2${NC}"
fi

echo ""
