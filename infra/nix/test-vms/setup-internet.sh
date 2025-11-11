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
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}🌐 DucksNest Test VM Internet Setup${NC}"
echo -e "${BLUE}====================================${NC}\n"

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

# Check if running with sudo when needed
if [ "$EUID" -ne 0 ]; then
    error "This script requires sudo privileges to set up TAP bridge and NAT"
    echo "Please run: sudo $0 $@"
    exit 1
fi

# Parse arguments
SETUP_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "This script sets up internet access for DucksNest test VMs by:"
            echo "  • Creating a TAP bridge (ducksnest-br0)"
            echo "  • Enabling IP forwarding"
            echo "  • Configuring NAT rules"
            echo ""
            echo "After running this script, you can start VMs with:"
            echo "  cd $BASE_DIR"
            echo "  $SCRIPT_DIR/build-vms.sh --internet"
            echo ""
            echo "Options:"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

section "Setting up TAP bridge for VM internet access..."

# Create bridge if it doesn't exist
if ! ip link show ducksnest-br0 >/dev/null 2>&1; then
    if ! ip link add ducksnest-br0 type bridge; then
        error "Failed to create bridge"
        exit 1
    fi
    if ! ip addr add 10.100.0.1/24 dev ducksnest-br0; then
        error "Failed to set bridge IP"
        exit 1
    fi
    if ! ip link set ducksnest-br0 up; then
        error "Failed to bring up bridge"
        exit 1
    fi
    success "Bridge created: ducksnest-br0 (10.100.0.1/24)"
else
    success "Bridge ducksnest-br0 already exists"
fi

# Create tap devices if they don't exist
section "Setting up TAP devices..."
for i in 0 1; do
    if ! ip link show tap$i >/dev/null 2>&1; then
        if ! ip tuntap add tap$i mode tap user $(logname 2>/dev/null || echo $SUDO_USER || echo "root"); then
            error "Failed to create tap$i"
            exit 1
        fi
        if ! ip link set tap$i master ducksnest-br0; then
            error "Failed to add tap$i to bridge"
            exit 1
        fi
        if ! ip link set tap$i up; then
            error "Failed to bring up tap$i"
            exit 1
        fi
    fi
done
success "TAP devices ready: tap0, tap1"

# Enable IP forwarding and NAT
section "Configuring IP forwarding and NAT..."

DEFAULT_UPLINK="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}' || true)"
if [ -z "$DEFAULT_UPLINK" ]; then
    warning "Could not determine default uplink interface; skipping NAT setup."
    warning "You may need to configure NAT manually if internet access is needed."
else
    # Enable IP forwarding
    if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)" -ne 1 ]; then
        if sysctl -w net.ipv4.ip_forward=1 >/dev/null; then
            success "Enabled IPv4 forwarding on host"
        else
            warning "Failed to enable net.ipv4.ip_forward"
        fi
    else
        success "IPv4 forwarding already enabled"
    fi

    # Determine which iptables command to use
    if command -v iptables >/dev/null 2>&1; then
        IPT_CMD="iptables"
    elif command -v iptables-nft >/dev/null 2>&1; then
        IPT_CMD="iptables-nft"
    else
        IPT_CMD=""
    fi

    if [ -n "$IPT_CMD" ]; then
        # Check if rule already exists before adding
        if ! $IPT_CMD -t nat -C POSTROUTING -s 10.100.0.0/24 -o "$DEFAULT_UPLINK" -j MASQUERADE 2>/dev/null; then
            if $IPT_CMD -t nat -A POSTROUTING -s 10.100.0.0/24 -o "$DEFAULT_UPLINK" -j MASQUERADE; then
                success "NAT configured via $IPT_CMD on interface $DEFAULT_UPLINK"
            else
                warning "Failed to add NAT rule via $IPT_CMD"
            fi
        else
            success "NAT rule already configured"
        fi
    else
        warning "No iptables-compatible command found; VMs may lack outbound internet."
    fi
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Internet setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Build and run the VMs:"
echo -e "     cd $BASE_DIR"
echo -e "     $SCRIPT_DIR/build-vms.sh --internet"
echo ""
echo -e "  2. Access the VMs once they're running:"
echo -e "     Control Plane: ssh root@10.100.0.2"
echo -e "     Worker Node:   ssh root@10.100.0.3"
echo ""
echo -e "  3. Inside the VMs, test internet access:"
echo -e "     ping 8.8.8.8"
echo ""
echo -e "${YELLOW}Note:${NC} Make sure the TAP bridge is set up before starting the VMs."
echo -e "      Run this script again if you restart the host."
