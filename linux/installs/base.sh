#!/usr/bin/env bash
# Base installation script for all Linux devices
# Installs core development tools and utilities

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}=== Base Tools Installation ===${NC}"
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

# 1. Install Vim
echo -e "${YELLOW}Installing vim...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD vim
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD vim-enhanced  # Enhanced vim without GUI dependencies
elif [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD vim
fi
echo -e "${GREEN}✓ Vim installed${NC}"
echo

# 2. Install Docker
echo -e "${YELLOW}Installing Docker...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD docker docker-compose
    sudo systemctl enable docker
    sudo systemctl start docker
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD dnf-plugins-core
    if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
        if [ "$DISTRO" = "rhel" ]; then
            # AlmaLinux/RHEL use different Docker repository
            sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/rhel/docker-ce.repo
        else
            # Fedora
            sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
        fi
    else
        echo -e "${BLUE}Docker repository already configured${NC}"
    fi
    $INSTALL_CMD docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
elif [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    $UPDATE_CMD
    $INSTALL_CMD docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Add current user to docker group
if ! groups $USER | grep -q docker; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed and user added to docker group${NC}"
    echo -e "${YELLOW}  NOTE: You need to log out and back in for docker group changes to take effect${NC}"
else
    echo -e "${GREEN}✓ Docker installed (user already in docker group)${NC}"
fi
echo

# 3. Install zellij
echo -e "${YELLOW}Installing zellij...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD zellij
else
    ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -sL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C /tmp
    sudo mv /tmp/zellij /usr/local/bin/zellij
fi
echo -e "${GREEN}✓ zellij installed${NC}"
echo

# 4. Install Python3 and pip
echo -e "${YELLOW}Installing Python3 and pip...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD python python-pip
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD python3 python3-pip
elif [ "$PKG_MANAGER" = "apt" ]; then
    $INSTALL_CMD python3 python3-pip
fi
echo -e "${GREEN}✓ Python3 and pip installed${NC}"
echo

# 5. Install Node Version Manager (nvm) and LTS Node
echo -e "${YELLOW}Installing Node Version Manager (nvm)...${NC}"
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Load nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install LTS version of Node
    echo -e "${YELLOW}Installing Node.js LTS...${NC}"
    nvm install --lts
    nvm use --lts
    echo -e "${GREEN}✓ nvm and Node.js LTS installed${NC}"
else
    echo -e "${GREEN}✓ nvm already installed${NC}"
    # Load nvm and install/update LTS
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    echo -e "${YELLOW}Installing/updating Node.js LTS...${NC}"
    nvm install --lts
    nvm use --lts
    echo -e "${GREEN}✓ Node.js LTS updated${NC}"
fi
echo

# 6. Install Development Tools
echo -e "${YELLOW}Installing development tools...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    sudo pacman -S --noconfirm base-devel
elif [ "$PKG_MANAGER" = "dnf" ]; then
    if [ "$DISTRO" = "rhel" ]; then
        sudo dnf groupinstall -y "Development Tools"
    else
        sudo dnf install -y @development-tools
    fi
elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt-get install -y build-essential
fi
echo -e "${GREEN}✓ Development tools installed${NC}"
echo

# 7. Install and configure Git
echo -e "${YELLOW}Installing git...${NC}"
$INSTALL_CMD git
echo -e "${GREEN}✓ Git installed${NC}"
echo

# Configure git if not already configured
if [ -z "$(git config --global user.name)" ]; then
    read -p "$(echo -e ${CYAN}Enter your Git name: ${NC})" git_name
    git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    read -p "$(echo -e ${CYAN}Enter your Git email: ${NC})" git_email
    git config --global user.email "$git_email"
fi

echo -e "${BLUE}Git configured with:${NC}"
echo -e "  ${BOLD}Name:${NC} $(git config --global user.name)"
echo -e "  ${BOLD}Email:${NC} $(git config --global user.email)"
echo

echo -e "${BOLD}${GREEN}=== Base Tools Installation Complete ===${NC}"
echo
echo -e "${YELLOW}IMPORTANT: If this is your first time installing Docker, you need to"
echo -e "log out and log back in for the docker group changes to take effect.${NC}"
