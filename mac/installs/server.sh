#!/usr/bin/env bash
# Server installation script for macOS
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

echo -e "${BOLD}${CYAN}=== Server Tools Installation (macOS) ===${NC}"
echo

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${RED}Error: Homebrew is not installed. Please run the base installation first.${NC}"
    exit 1
fi

# Update Homebrew
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update
echo

# 1. Enable SSH Server (Remote Login)
echo -e "${YELLOW}Configuring SSH Server (Remote Login)...${NC}"
if sudo systemsetup -getremotelogin | grep -q "Off"; then
    read -p "$(echo -e ${CYAN})Remote Login is currently OFF. Enable it? (y/n) $(echo -e ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemsetup -setremotelogin on
        echo -e "${GREEN}✓ Remote Login (SSH) enabled${NC}"
    else
        echo -e "${YELLOW}Skipped enabling Remote Login${NC}"
    fi
else
    echo -e "${GREEN}✓ Remote Login (SSH) already enabled${NC}"
fi
echo

# Configure SSH (optional enhancements)
read -p "$(echo -e ${CYAN})Do you want to configure SSH for key-only authentication? (recommended for servers) (y/n) $(echo -e ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup original config if it exists
    if [ -f /etc/ssh/sshd_config ]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

        # Disable password authentication
        sudo sed -i '' 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i '' 's/^#*PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

        # Restart SSH service
        sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
        sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist

        echo -e "${GREEN}✓ SSH configured for key-only authentication${NC}"
        echo -e "${YELLOW}  NOTE: Make sure you have added your public key to ~/.ssh/authorized_keys"
        echo -e "        before closing this session, or you may lock yourself out!${NC}"
    else
        echo -e "${YELLOW}SSH config file not found at expected location${NC}"
    fi
fi
echo

# Optional: Install additional server utilities
read -p "$(echo -e ${CYAN})Install additional server monitoring tools? (htop, ncdu) (y/n) $(echo -e ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installing monitoring tools...${NC}"
    brew install htop ncdu
    echo -e "${GREEN}✓ Monitoring tools installed${NC}"
fi
echo

echo -e "${BOLD}${GREEN}=== Server Tools Installation Complete ===${NC}"
echo
echo -e "${BLUE}Remote Login Status:${NC}"
sudo systemsetup -getremotelogin
