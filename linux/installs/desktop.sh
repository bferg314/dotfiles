#!/usr/bin/env bash
# Desktop installation script for Linux workstations
# Installs desktop applications and tools

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}=== Desktop Applications Installation ===${NC}"
echo

# Detect package manager
if command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm"
    UPDATE_CMD="sudo pacman -Sy"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf check-update || true"
elif command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update"
else
    echo "Error: Unable to detect package manager (pacman, dnf, or apt)"
    exit 1
fi

echo -e "${BLUE}Detected package manager: ${BOLD}$PKG_MANAGER${NC}"
echo

# Update package lists
echo -e "${YELLOW}Updating package lists...${NC}"
$UPDATE_CMD
echo

# Install and setup Flatpak if on Fedora/dnf
if [ "$PKG_MANAGER" = "dnf" ]; then
    if ! command -v flatpak >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing Flatpak...${NC}"
        $INSTALL_CMD flatpak
    fi

    # Add Flathub repository if not already added
    if ! flatpak remotes | grep -q flathub; then
        echo -e "${YELLOW}Adding Flathub repository...${NC}"
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    echo -e "${GREEN}✓ Flatpak ready${NC}"
    echo
fi

# 1. Install Steam
echo -e "${YELLOW}Installing Steam...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    # Enable multilib for Steam on Arch
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo "Enabling multilib repository..."
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi
    $INSTALL_CMD steam
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # Enable RPM Fusion for Steam on Fedora
    if ! dnf repolist | grep -q rpmfusion; then
        echo "Enabling RPM Fusion repositories..."
        $INSTALL_CMD https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
        $INSTALL_CMD https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    fi
    $INSTALL_CMD steam
elif [ "$PKG_MANAGER" = "apt" ]; then
    # Add multiverse for Steam on Ubuntu
    sudo add-apt-repository -y multiverse
    $UPDATE_CMD
    $INSTALL_CMD steam
fi
echo -e "${GREEN}✓ Steam installed${NC}"
echo

# 2. Install Firefox
echo -e "${YELLOW}Installing Firefox...${NC}"
$INSTALL_CMD firefox
echo -e "${GREEN}✓ Firefox installed${NC}"
echo

# 3. Install VS Code (official)
echo -e "${YELLOW}Installing VS Code...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    # Install from AUR helper or official repo
    if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm visual-studio-code-bin
    elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm visual-studio-code-bin
    else
        echo "Note: Install 'yay' or 'paru' AUR helper for VS Code, or install manually"
        echo "Skipping VS Code installation"
    fi
elif [ "$PKG_MANAGER" = "dnf" ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    $UPDATE_CMD
    $INSTALL_CMD code
elif [ "$PKG_MANAGER" = "apt" ]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg
    $UPDATE_CMD
    $INSTALL_CMD code
fi
echo -e "${GREEN}✓ VS Code installed${NC}"
echo

# 4. Install Obsidian
echo -e "${YELLOW}Installing Obsidian...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm obsidian
    elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm obsidian
    else
        echo "Note: Install 'yay' or 'paru' AUR helper for Obsidian"
        echo "Skipping Obsidian installation"
    fi
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # Install Obsidian via Flatpak
    flatpak install -y flathub md.obsidian.Obsidian
elif [ "$PKG_MANAGER" = "apt" ]; then
    # Download and install from GitHub releases
    OBSIDIAN_VERSION=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')
    wget -O obsidian.deb "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
    sudo apt install -y ./obsidian.deb
    rm obsidian.deb
fi
echo -e "${GREEN}✓ Obsidian installed${NC}"
echo

# 5. Install Spotify
echo -e "${YELLOW}Installing Spotify...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm spotify
    elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm spotify
    else
        echo "Note: Install 'yay' or 'paru' AUR helper for Spotify"
        echo "Skipping Spotify installation"
    fi
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # Install Spotify via Flatpak
    flatpak install -y flathub com.spotify.Client
elif [ "$PKG_MANAGER" = "apt" ]; then
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    $UPDATE_CMD
    $INSTALL_CMD spotify-client
fi
echo -e "${GREEN}✓ Spotify installed${NC}"
echo

# 6. Install Discord
echo -e "${YELLOW}Installing Discord...${NC}"
if [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD discord
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # Install Discord via Flatpak
    flatpak install -y flathub com.discordapp.Discord
elif [ "$PKG_MANAGER" = "apt" ]; then
    wget -O discord.deb "https://discord.com/api/download?platform=linux&format=deb"
    sudo apt install -y ./discord.deb
    rm discord.deb
fi
echo -e "${GREEN}✓ Discord installed${NC}"
echo

echo -e "${BOLD}${GREEN}=== Desktop Applications Installation Complete ===${NC}"
