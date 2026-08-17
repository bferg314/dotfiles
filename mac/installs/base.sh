#!/usr/bin/env bash
# Base installation script for macOS
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

echo -e "${BOLD}${CYAN}=== Base Tools Installation (macOS) ===${NC}"
echo

# Check if Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    echo -e "${GREEN}✓ Homebrew installed${NC}"
else
    echo -e "${GREEN}✓ Homebrew already installed${NC}"
fi
echo

# Update Homebrew
echo -e "${YELLOW}Updating Homebrew...${NC}"
brew update
echo

# 1. Install Vim with clipboard support
echo -e "${YELLOW}Installing vim...${NC}"
if ! brew list vim &>/dev/null; then
    brew install vim
    echo -e "${GREEN}✓ Vim installed${NC}"
else
    echo -e "${GREEN}✓ Vim already installed${NC}"
fi
echo

# 2. Install Docker Desktop for Mac
echo -e "${YELLOW}Installing Docker Desktop...${NC}"
if ! brew list --cask docker &>/dev/null; then
    brew install --cask docker
    echo -e "${GREEN}✓ Docker Desktop installed${NC}"
    echo -e "${YELLOW}  NOTE: You need to open Docker Desktop from Applications to complete setup${NC}"
else
    echo -e "${GREEN}✓ Docker Desktop already installed${NC}"
fi
echo

# 3. Install zellij
echo -e "${YELLOW}Installing zellij...${NC}"
brew install zellij
echo -e "${GREEN}✓ zellij installed${NC}"
echo

# 3b. Install the terminal font
#
# Homebrew has font-fira-code-nerd-font, but this pulls the same GitHub release
# that the Linux and Windows installers use so every machine ends up on an
# identical version. Only the Mono variant is installed; the archive also
# carries the proportional and non-Mono families.
echo -e "${YELLOW}Installing FiraCode Nerd Font Mono...${NC}"
FONT_DIR="$HOME/Library/Fonts"
if ls "$FONT_DIR"/FiraCodeNerdFontMono-*.ttf >/dev/null 2>&1; then
    echo -e "${GREEN}✓ FiraCode Nerd Font Mono already installed${NC}"
else
    FONT_TAG="$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest |
        grep '"tag_name"' | head -n1 | cut -d'"' -f4)"
    if [ -z "$FONT_TAG" ]; then
        echo -e "${YELLOW}⚠ Could not determine the latest nerd-fonts release; skipping font${NC}"
    else
        FONT_TMP="$(mktemp -d)"
        if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_TAG}/FiraCode.tar.xz" |
                tar -xJ -C "$FONT_TMP"; then
            mkdir -p "$FONT_DIR"
            cp "$FONT_TMP"/FiraCodeNerdFontMono-*.ttf "$FONT_DIR/"
            echo -e "${GREEN}✓ FiraCode Nerd Font Mono installed (${FONT_TAG})${NC}"
        else
            echo -e "${YELLOW}⚠ Failed to download the font; prompt glyphs will not render${NC}"
        fi
        rm -rf "$FONT_TMP"
    fi
fi
echo

# 4. Install Python and pip
#
# Pinned to the series this repo targets rather than brew's rolling `python3`,
# so macOS, Linux and Windows stay on the same one. The fallback matters when
# Homebrew has not yet published the formula.
PYTHON_SERIES="3.14"
echo -e "${YELLOW}Installing Python ${PYTHON_SERIES}...${NC}"
if brew install "python@${PYTHON_SERIES}"; then
    echo -e "${GREEN}✓ Python ${PYTHON_SERIES} installed${NC}"
    # Keg-only formulae are not linked into the prefix; python3 keeps pointing
    # at whatever else is installed until the versioned bin dir is on PATH.
    PYTHON_PREFIX="$(brew --prefix "python@${PYTHON_SERIES}" 2>/dev/null)"
    if [ -n "$PYTHON_PREFIX" ] && [ -d "$PYTHON_PREFIX/libexec/bin" ]; then
        echo -e "${BLUE}  → For an unversioned python3/pip3, put this on PATH:${NC}"
        echo -e "    ${BOLD}${PYTHON_PREFIX}/libexec/bin${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No python@${PYTHON_SERIES} formula; falling back to python3${NC}"
    brew install python3
    echo -e "${GREEN}✓ Python $(python3 --version 2>&1 | awk '{print $2}') installed${NC}"
fi
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

# 6. Install Command Line Developer Tools
echo -e "${YELLOW}Checking Xcode Command Line Tools...${NC}"
if ! xcode-select -p &>/dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo -e "${YELLOW}Please complete the Xcode Command Line Tools installation and run this script again.${NC}"
    exit 0
else
    echo -e "${GREEN}✓ Xcode Command Line Tools already installed${NC}"
fi
echo

# 6b. Install the Rust toolchain
#
# After the Command Line Tools above: the default toolchain links with cc.
# The upstream installer rather than Homebrew's rustup formula, so macOS, Linux
# and Windows all manage toolchains the same way.
#
# --no-modify-path, because rustup would otherwise append its own PATH line to
# ~/.zshenv, ~/.bashrc and ~/.profile. zshrc.d/rust.zshrc does that instead, so
# the shell config stays in the repo.
echo -e "${YELLOW}Installing rustup...${NC}"
# An `if` rather than `[ -f ... ] && ...`: under set -e a failing test as the
# last command of an AND-list takes the whole script down with it.
if [ -f "$HOME/.cargo/env" ]; then \. "$HOME/.cargo/env"; fi
if command -v rustup >/dev/null 2>&1; then
    echo -e "${GREEN}✓ rustup already installed ($(rustup --version 2>/dev/null | head -n1))${NC}"
    rustup update || echo -e "${YELLOW}⚠ rustup update failed; the existing toolchain is unchanged${NC}"
else
    if curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
            sh -s -- -y --no-modify-path --default-toolchain stable; then
        if [ -f "$HOME/.cargo/env" ]; then \. "$HOME/.cargo/env"; fi
        echo -e "${GREEN}✓ rustup installed ($(rustup --version 2>/dev/null | head -n1))${NC}"
    else
        echo -e "${YELLOW}⚠ rustup install failed; continuing without Rust (see https://rustup.rs)${NC}"
    fi
fi
echo

# 7. Install and configure Git
echo -e "${YELLOW}Installing git...${NC}"
brew install git
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

# 8. Install GitHub CLI
echo -e "${YELLOW}Installing GitHub CLI...${NC}"
brew install gh
echo -e "${GREEN}✓ GitHub CLI installed${NC}"
echo

echo -e "${BOLD}${GREEN}=== Base Tools Installation Complete ===${NC}"
echo
echo -e "${YELLOW}IMPORTANT: If Docker Desktop was just installed, open it from Applications"
echo -e "to complete the setup and grant necessary permissions.${NC}"
echo
echo -e "${BLUE}Authenticate the GitHub CLI when you are ready: ${BOLD}gh auth login${NC}"
echo -e "${BLUE}cargo and rustc land on PATH in a new shell (zshrc.d/rust.zshrc): ${BOLD}rustup show${NC}"
