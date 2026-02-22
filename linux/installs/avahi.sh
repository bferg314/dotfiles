#!/usr/bin/env bash
# Avahi (mDNS/DNS-SD) installation script
# Installs avahi daemon and tools, starts the service, and opens firewall ports

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}=== Avahi (mDNS) Installation ===${NC}"
echo

# Detect distribution and package manager
if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    DISTRO="arch"
    INSTALL_CMD="sudo pacman -S --noconfirm"
    UPDATE_CMD="sudo pacman -Sy"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf check-update || true"

    # Detect if Fedora or AlmaLinux/RHEL
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "almalinux" ]] || [[ "$ID" == "rhel" ]] || [[ "$ID" == "rocky" ]]; then
            DISTRO="rhel"
        else
            DISTRO="fedora"
        fi
    else
        DISTRO="fedora"
    fi
elif command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    DISTRO="debian"
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update"
else
    echo "Error: Unable to detect package manager (pacman, dnf, or apt)"
    exit 1
fi

echo -e "${BLUE}Detected package manager: ${BOLD}$PKG_MANAGER${NC}"
if [ "$PKG_MANAGER" = "dnf" ]; then
    echo -e "${BLUE}Distribution type: ${BOLD}$DISTRO${NC}"
fi
echo

# Update package lists
echo -e "${YELLOW}Updating package lists...${NC}"
$UPDATE_CMD
echo

# 1. Install Avahi daemon and tools
echo -e "${YELLOW}Installing Avahi...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD avahi nss-mdns
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD avahi avahi-tools nss-mdns
elif [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD avahi-daemon avahi-utils libnss-mdns
fi
echo -e "${GREEN}✓ Avahi installed${NC}"
echo

# 2. Enable and start avahi-daemon
echo -e "${YELLOW}Enabling avahi-daemon service...${NC}"
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
echo -e "${GREEN}✓ avahi-daemon enabled and started${NC}"
echo

# 3. Ensure NSS mdns is configured
if [ -f /etc/nsswitch.conf ]; then
    if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
        echo -e "${YELLOW}Configuring NSS for mDNS resolution...${NC}"
        sudo sed -i 's/^hosts:.*/hosts:      files mdns_minimal [NOTFOUND=return] dns/' /etc/nsswitch.conf
        echo -e "${GREEN}✓ NSS configured for mDNS${NC}"
    else
        echo -e "${GREEN}✓ NSS already configured for mDNS${NC}"
    fi
fi
echo

# 4. Open firewall ports for mDNS (UDP 5353)
echo -e "${YELLOW}Configuring firewall for mDNS...${NC}"
if command -v firewall-cmd >/dev/null 2>&1; then
    # firewalld (Fedora, RHEL, Arch with firewalld)
    if sudo firewall-cmd --state >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --add-service=mdns
        sudo firewall-cmd --reload
        echo -e "${GREEN}✓ firewalld: mDNS service added${NC}"
    else
        echo -e "${YELLOW}  firewalld is installed but not running, skipping${NC}"
    fi
elif command -v ufw >/dev/null 2>&1; then
    # UFW (Ubuntu/Debian)
    if sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow 5353/udp comment "mDNS (Avahi)"
        echo -e "${GREEN}✓ ufw: mDNS port 5353/udp allowed${NC}"
    else
        echo -e "${YELLOW}  ufw is installed but not active, skipping${NC}"
    fi
elif command -v iptables >/dev/null 2>&1; then
    # Raw iptables fallback
    if sudo iptables -L INPUT -n 2>/dev/null | grep -q "5353"; then
        echo -e "${GREEN}✓ iptables: mDNS port already open${NC}"
    else
        sudo iptables -A INPUT -p udp --dport 5353 -j ACCEPT
        echo -e "${GREEN}✓ iptables: mDNS port 5353/udp allowed${NC}"
        echo -e "${YELLOW}  NOTE: iptables rules are not persistent by default.${NC}"
        echo -e "${YELLOW}  Install iptables-persistent (Debian) or iptables-services (RHEL) to persist.${NC}"
    fi
else
    echo -e "${YELLOW}  No supported firewall detected, skipping${NC}"
fi
echo

echo -e "${BOLD}${GREEN}=== Avahi Installation Complete ===${NC}"
echo
echo -e "${BLUE}This machine is now discoverable as: ${BOLD}$(hostname).local${NC}"
echo
echo -e "${BLUE}Avahi daemon status:${NC}"
sudo systemctl status avahi-daemon --no-pager | head -n 3
