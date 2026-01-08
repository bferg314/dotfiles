#!/usr/bin/env bash
# Server installation script for Linux servers
# Installs server-specific tools and utilities

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}=== Server Tools Installation ===${NC}"
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
        DISTRO="fedora"  # Default to Fedora if can't detect
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

# 1. Install and configure SSH Server
echo -e "${YELLOW}Installing SSH Server...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD openssh
    sudo systemctl enable sshd
    sudo systemctl start sshd
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD openssh-server
    sudo systemctl enable sshd
    sudo systemctl start sshd
elif [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
fi
echo -e "${GREEN}✓ SSH Server installed and enabled${NC}"
echo

# Configure SSH (optional enhancements)
read -p "$(echo -e ${CYAN})Do you want to configure SSH for key-only authentication? (recommended for servers) (y/n) $(echo -e ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup original config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Disable password authentication
    sudo sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

    # Restart SSH service
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo systemctl restart ssh
    else
        sudo systemctl restart sshd
    fi

    echo -e "${GREEN}✓ SSH configured for key-only authentication${NC}"
    echo -e "${YELLOW}  NOTE: Make sure you have added your public key to ~/.ssh/authorized_keys"
    echo -e "        before closing this session, or you may lock yourself out!${NC}"
fi
echo

# Optional: Install additional server utilities
read -p "$(echo -e ${CYAN})Install additional server monitoring tools? (htop, ncdu, net-tools) (y/n) $(echo -e ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing monitoring tools...${NC}"
    if [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD htop ncdu net-tools
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD htop ncdu net-tools
    elif [ "$PKG_MANAGER" = "apt" ]; then
        $INSTALL_CMD htop ncdu net-tools
    fi
    echo -e "${GREEN}✓ Monitoring tools installed${NC}"
fi
echo

echo -e "${BOLD}${GREEN}=== Server Tools Installation Complete ===${NC}"
echo
echo -e "${BLUE}SSH Server Status:${NC}"
if [ "$PKG_MANAGER" = "apt" ]; then
    sudo systemctl status ssh --no-pager | head -n 3
else
    sudo systemctl status sshd --no-pager | head -n 3
fi
