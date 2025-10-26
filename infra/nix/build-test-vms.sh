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
USE_TAP=false

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
        --tap|--internet)
            USE_TAP=true
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
            echo "  --tap         Setup tap bridge and run VMs with networking (requires sudo)"
            echo "  --internet    Alias for --tap: enables internet access for VMs"
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

# Create wrapper scripts for VMs that replace user-mode networking with TAP
if [ "$BUILD_CP" = true ]; then
    cat > "$SCRIPT_DIR/run-cp-vm-wrapper.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

VM_SCRIPT="$(dirname "$0")/result-cp/bin/run-ducksnest-test-controlplane-vm"
TAP_DEVICE="${TAP_DEVICE:-tap0}"
MAC_ADDRESS="${MAC_ADDRESS:-52:54:00:12:34:01}"

# Replace user-mode networking with TAP networking in the VM script
# Pattern: -net nic,netdev=user.0,model=virtio -netdev user,id=user.0,"$QEMU_NET_OPTS"
# Replace: -net nic,netdev=tap0,model=virtio,mac=X -netdev tap,id=tap0,ifname=Y,script=no,downscript=no

sed 's| -net nic,netdev=user\.0,model=virtio -netdev user,id=user\.0,"[^"]*"| -net nic,netdev=tap0,model=virtio,macaddr='"${MAC_ADDRESS}"' -netdev tap,id=tap0,ifname='"${TAP_DEVICE}"',script=no,downscript=no|g' "$VM_SCRIPT" | bash
EOF
    chmod +x "$SCRIPT_DIR/run-cp-vm-wrapper.sh"
fi

if [ "$BUILD_WN" = true ]; then
    cat > "$SCRIPT_DIR/run-wn-vm-wrapper.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

VM_SCRIPT="$(dirname "$0")/result-wn/bin/run-ducksnest-test-worker-node-vm"
TAP_DEVICE="${TAP_DEVICE:-tap1}"
MAC_ADDRESS="${MAC_ADDRESS:-52:54:00:12:34:02}"

# Replace user-mode networking with TAP networking in the VM script
sed 's| -net nic,netdev=user\.0,model=virtio -netdev user,id=user\.0,"[^"]*"| -net nic,netdev=tap1,model=virtio,macaddr='"${MAC_ADDRESS}"' -netdev tap,id=tap1,ifname='"${TAP_DEVICE}"',script=no,downscript=no|g' "$VM_SCRIPT" | bash
EOF
    chmod +x "$SCRIPT_DIR/run-wn-vm-wrapper.sh"
fi

# Show how to run
echo -e "\n${BLUE}To run the VMs with internet access:${NC}"
echo -e "  ${YELLOW}Quick start:${NC}"
echo -e "    $0 --internet"
echo -e "    This will:"
echo -e "      • Build the VMs"
echo -e "      • Setup TAP bridge for networking"
echo -e "      • Enable NAT for internet access"
echo -e "      • Launch both VMs in tmux"
echo -e "      • VMs will be at 10.100.0.2 (CP) and 10.100.0.3 (WN)"

echo -e "\n${BLUE}To run the VMs manually:${NC}"
if [ "$BUILD_CP" = true ]; then
    echo -e "  ${YELLOW}Control Plane:${NC}"
    echo -e "    ./result-cp/bin/run-ducksnest-test-controlplane-vm"
    echo -e "    Or with custom QEMU options:"
    echo -e "    QEMU_OPTS=\"-nographic\" ./run-cp-vm-wrapper.sh"
fi
if [ "$BUILD_WN" = true ]; then
    echo -e "  ${YELLOW}Worker Node:${NC}"
    echo -e "    ./result-wn/bin/run-ducksnest-test-worker-node-vm"
    echo -e "    Or with custom QEMU options:"
    echo -e "    QEMU_OPTS=\"-nographic\" ./run-wn-vm-wrapper.sh"
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

  # Setup tap bridge if requested
  if [ "$USE_TAP" = true ]; then
    section "Setting up tap bridge for inter-VM networking..."

    # Create bridge if it doesn't exist
    if ! sudo ip link show ducksnest-br0 >/dev/null 2>&1; then
      sudo ip link add ducksnest-br0 type bridge || error "Failed to create bridge"
      sudo ip addr add 10.100.0.1/24 dev ducksnest-br0 || error "Failed to set bridge IP"
      sudo ip link set ducksnest-br0 up || error "Failed to bring up bridge"
      success "Bridge created: ducksnest-br0 (10.100.0.1/24)"
    else
      success "Bridge ducksnest-br0 already exists"
    fi

    # Create tap devices if they don't exist
    for i in 0 1; do
      if ! sudo ip link show tap$i >/dev/null 2>&1; then
        sudo ip tuntap add tap$i mode tap user $(whoami) || error "Failed to create tap$i"
        sudo ip link set tap$i master ducksnest-br0 || error "Failed to add tap$i to bridge"
        sudo ip link set tap$i up || error "Failed to bring up tap$i"
      fi
    done
    success "Tap devices created: tap0, tap1"

    # Enable IP forwarding and NAT so VMs can reach the outside world
    DEFAULT_UPLINK="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')"
    if [ -z "$DEFAULT_UPLINK" ]; then
      warning "Could not determine default uplink interface; skipping NAT setup."
    else
      if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)" -ne 1 ]; then
        if sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null; then
          success "Enabled IPv4 forwarding on host"
        else
          warning "Failed to enable net.ipv4.ip_forward"
        fi
      fi

      if command -v iptables >/dev/null 2>&1; then
        IPT_CMD="iptables"
      elif command -v iptables-nft >/dev/null 2>&1; then
        IPT_CMD="iptables-nft"
      else
        IPT_CMD=""
      fi

      if [ -n "$IPT_CMD" ]; then
        if ! sudo "$IPT_CMD" -t nat -C POSTROUTING -s 10.100.0.0/24 -o "$DEFAULT_UPLINK" -j MASQUERADE 2>/dev/null; then
          sudo "$IPT_CMD" -t nat -A POSTROUTING -s 10.100.0.0/24 -o "$DEFAULT_UPLINK" -j MASQUERADE || warning "Failed to add $IPT_CMD MASQUERADE rule"
        fi
        if ! sudo "$IPT_CMD" -C FORWARD -i ducksnest-br0 -o "$DEFAULT_UPLINK" -j ACCEPT 2>/dev/null; then
          sudo "$IPT_CMD" -A FORWARD -i ducksnest-br0 -o "$DEFAULT_UPLINK" -j ACCEPT || warning "Failed to add $IPT_CMD forward rule (bridge → uplink)"
        fi
        if ! sudo "$IPT_CMD" -C FORWARD -i "$DEFAULT_UPLINK" -o ducksnest-br0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
          sudo "$IPT_CMD" -A FORWARD -i "$DEFAULT_UPLINK" -o ducksnest-br0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || warning "Failed to add $IPT_CMD forward rule (uplink → bridge)"
        fi
        success "NAT + forwarding configured via $IPT_CMD on interface $DEFAULT_UPLINK"
      else
        warning "No iptables-compatible command found; VMs may lack outbound internet."
      fi
    fi

    # Prepare tap networking arguments with unique MACs for each VM
    CP_QEMU_OPTS=""
    WN_QEMU_OPTS=""
  else
    warning "Using user-mode networking"
    warning "  • VMs can reach the internet but cannot communicate with each other"
    warning "  • For full networking with VM-to-VM communication, use: $0 --internet"

    # QEMU options for tmux integration
    CP_QEMU_OPTS="-display none -nographic -serial stdio -monitor none"
    WN_QEMU_OPTS="-display none -nographic -serial stdio -monitor none"
  fi

  # Control Plane 창 생성 + 실행 (작업 디렉토리 고정 + bash -lc)
  tmux new-session -d -s ducksnest-test -n control -c "$SCRIPT_DIR" \
  "bash -lc 'QEMU_OPTS=\"'"${CP_QEMU_OPTS}"'\" ./run-cp-vm-wrapper.sh 2>&1 | tee cp.log; echo; read -n1 -p \"[CP ENDED] Press any key...]\"'"

  success "Control Plane VM launched in tmux window 'control'."


  # Worker 창 생성 + 실행(선택)
  if [ "$BUILD_WN" = true ]; then
    tmux new-window -t ducksnest-test -n worker -c "$SCRIPT_DIR" \
    "bash -lc 'QEMU_OPTS=\"'"${WN_QEMU_OPTS}"'\" ./run-wn-vm-wrapper.sh 2>&1 | tee wn.log; echo; read -n1 -p \"[WN ENDED] Press any key...]\"'"
    success "Worker Node VM launched in tmux window 'worker'."
  fi

  # 이미 tmux 안이면 attach 대신 switch (중첩 경고 방지)
  if [ -n "${TMUX-}" ]; then
    tmux switch-client -t ducksnest-test
  else
    tmux attach -t ducksnest-test
  fi
fi
