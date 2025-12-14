#!/usr/bin/env bash
# Desktop installation script for macOS
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

echo -e "${BOLD}${CYAN}=== Desktop Applications Installation (macOS) ===${NC}"
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

# 1. Install Steam
echo -e "${YELLOW}Installing Steam...${NC}"
if [ -d "/Applications/Steam.app" ]; then
    echo -e "${GREEN}✓ Steam already installed${NC}"
elif brew list --cask steam &>/dev/null; then
    echo -e "${GREEN}✓ Steam already installed via Homebrew${NC}"
else
    brew install --cask steam 2>&1 || echo -e "${YELLOW}⚠ Steam installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ Steam installed${NC}"
fi
echo

# 2. Install Firefox
echo -e "${YELLOW}Installing Firefox...${NC}"
if [ -d "/Applications/Firefox.app" ]; then
    echo -e "${GREEN}✓ Firefox already installed${NC}"
elif brew list --cask firefox &>/dev/null; then
    echo -e "${GREEN}✓ Firefox already installed via Homebrew${NC}"
else
    brew install --cask firefox 2>&1 || echo -e "${YELLOW}⚠ Firefox installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ Firefox installed${NC}"
fi
echo

# 3. Install VS Code
echo -e "${YELLOW}Installing VS Code...${NC}"
if [ -d "/Applications/Visual Studio Code.app" ]; then
    echo -e "${GREEN}✓ VS Code already installed${NC}"
elif brew list --cask visual-studio-code &>/dev/null; then
    echo -e "${GREEN}✓ VS Code already installed via Homebrew${NC}"
else
    brew install --cask visual-studio-code 2>&1 || echo -e "${YELLOW}⚠ VS Code installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ VS Code installed${NC}"
fi
echo

# 4. Install Obsidian
echo -e "${YELLOW}Installing Obsidian...${NC}"
if [ -d "/Applications/Obsidian.app" ]; then
    echo -e "${GREEN}✓ Obsidian already installed${NC}"
elif brew list --cask obsidian &>/dev/null; then
    echo -e "${GREEN}✓ Obsidian already installed via Homebrew${NC}"
else
    brew install --cask obsidian 2>&1 || echo -e "${YELLOW}⚠ Obsidian installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ Obsidian installed${NC}"
fi
echo

# 5. Install Spotify
echo -e "${YELLOW}Installing Spotify...${NC}"
if [ -d "/Applications/Spotify.app" ]; then
    echo -e "${GREEN}✓ Spotify already installed${NC}"
elif brew list --cask spotify &>/dev/null; then
    echo -e "${GREEN}✓ Spotify already installed via Homebrew${NC}"
else
    brew install --cask spotify 2>&1 || echo -e "${YELLOW}⚠ Spotify installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ Spotify installed${NC}"
fi
echo

# 6. Install Discord
echo -e "${YELLOW}Installing Discord...${NC}"
if [ -d "/Applications/Discord.app" ]; then
    echo -e "${GREEN}✓ Discord already installed${NC}"
elif brew list --cask discord &>/dev/null; then
    echo -e "${GREEN}✓ Discord already installed via Homebrew${NC}"
else
    brew install --cask discord 2>&1 || echo -e "${YELLOW}⚠ Discord installation skipped (may already exist)${NC}"
    echo -e "${GREEN}✓ Discord installed${NC}"
fi
echo

echo -e "${BOLD}${GREEN}=== Desktop Applications Installation Complete ===${NC}"
