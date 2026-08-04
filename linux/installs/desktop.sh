#!/usr/bin/env bash
# Desktop installation script for Linux workstations
# Installs desktop applications and tools

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo -e "${BOLD}${CYAN}=== Desktop Applications Installation ===${NC}"
echo

detect_distro
make_tmpdir

# Update package lists
step "Updating package lists..."
pkg_update
echo

# Fedora/RHEL get several apps from Flathub
if [ "$PKG_MANAGER" = "dnf" ]; then
    ensure_flatpak
    ok "Flatpak ready"
    echo
fi

# Install GUI Vim with clipboard support (desktop environments)
step "Installing GUI Vim with clipboard support..."
case "$PKG_MANAGER" in
    pacman) pkg_install gvim ;;      # gvim provides GUI and clipboard support
    dnf)    pkg_install vim-X11 ;;   # vim-X11 provides GUI and clipboard support
    apt)    pkg_install vim-gtk3 ;;  # vim-gtk3 provides GUI and clipboard support
esac
ok "GUI Vim installed"
echo

# 1. Install Steam
step "Installing Steam..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    # Enable multilib for Steam on Arch
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        info "Enabling multilib repository..."
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf > /dev/null
        sudo pacman -Sy
    fi
    pkg_install steam
elif [ "$PKG_MANAGER" = "dnf" ]; then
    if [ "$DISTRO" = "fedora" ]; then
        # Enable RPM Fusion for Steam on Fedora
        if ! dnf repolist | grep -q rpmfusion; then
            info "Enabling RPM Fusion repositories..."
            pkg_install \
                "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
                "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
        fi
        pkg_install steam
    else
        # AlmaLinux/RHEL: Steam is not packaged, use Flatpak
        info "Installing Steam via Flatpak (RHEL-based distro)..."
        flatpak install -y flathub com.valvesoftware.Steam
    fi
elif [ "$PKG_MANAGER" = "apt" ]; then
    # Steam needs 32-bit libraries on both Debian and Ubuntu (x86 only)
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
        sudo dpkg --add-architecture i386
    fi
    if [ "$DISTRO" = "ubuntu" ]; then
        pkg_install software-properties-common
        sudo add-apt-repository -y multiverse
    else
        # Debian ships Steam in non-free, not multiverse (an Ubuntu-only component)
        if ! grep -rqs "non-free" /etc/apt/sources.list /etc/apt/sources.list.d/; then
            warn "Steam lives in Debian's non-free component."
            warn "Add 'non-free non-free-firmware' to your apt sources if the install fails."
        fi
    fi
    pkg_update
    # Recent releases ship 'steam-installer'; older ones only 'steam'
    pkg_install steam-installer || pkg_install steam
fi
ok "Steam installed"
echo

# 2. Install Firefox
step "Installing Firefox..."
pkg_install firefox
ok "Firefox installed"
echo

# 3. Install VS Code (official)
step "Installing VS Code..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    aur_install visual-studio-code-bin || true
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # VS Code repository works on both Fedora and RHEL-based distros
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
    pkg_update
    pkg_install code
elif [ "$PKG_MANAGER" = "apt" ]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$TMP_DIR/packages.microsoft.gpg"
    sudo install -D -o root -g root -m 644 "$TMP_DIR/packages.microsoft.gpg" /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    pkg_update
    pkg_install code
fi
ok "VS Code installed"
echo

# 4. Install Obsidian
step "Installing Obsidian..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    aur_install obsidian || true
elif [ "$PKG_MANAGER" = "dnf" ]; then
    flatpak install -y flathub md.obsidian.Obsidian
elif [ "$PKG_MANAGER" = "apt" ]; then
    OBSIDIAN_VERSION="$(github_latest_tag obsidianmd/obsidian-releases | sed 's/^v//')"
    if [ -n "$OBSIDIAN_VERSION" ]; then
        curl -fsSL -o "$TMP_DIR/obsidian.deb" \
            "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
        sudo apt-get install -y "$TMP_DIR/obsidian.deb"
    else
        warn "Could not determine the latest Obsidian release, skipping"
    fi
fi
ok "Obsidian installed"
echo

# 5. Install Spotify
step "Installing Spotify..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    aur_install spotify || true
elif [ "$PKG_MANAGER" = "dnf" ]; then
    flatpak install -y flathub com.spotify.Client
elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg |
        sudo gpg --dearmor --yes -o /etc/apt/keyrings/spotify.gpg
    echo "deb [signed-by=/etc/apt/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" |
        sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
    pkg_update
    pkg_install spotify-client
fi
ok "Spotify installed"
echo

# 6. Install Discord
step "Installing Discord..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install discord
elif [ "$PKG_MANAGER" = "dnf" ]; then
    flatpak install -y flathub com.discordapp.Discord
elif [ "$PKG_MANAGER" = "apt" ]; then
    curl -fsSL -o "$TMP_DIR/discord.deb" "https://discord.com/api/download?platform=linux&format=deb"
    sudo apt-get install -y "$TMP_DIR/discord.deb"
fi
ok "Discord installed"
echo

# 7. Install GitHub Desktop
step "Installing GitHub Desktop..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    aur_install github-desktop-bin || true
elif [ "$PKG_MANAGER" = "dnf" ]; then
    flatpak install -y flathub io.github.shiftey.Desktop
elif [ "$PKG_MANAGER" = "apt" ]; then
    # Resolve the real asset URL from the release API. A literal '*' in the URL
    # is not a glob -- wget would just download a file named with an asterisk.
    DEB_ARCH="$(dpkg --print-architecture)"
    GHD_URL="$(curl -fsSL https://api.github.com/repos/shiftkey/desktop/releases/latest |
        grep -o "\"browser_download_url\": *\"[^\"]*linux-${DEB_ARCH}[^\"]*\.deb\"" |
        head -n1 | cut -d'"' -f4)"
    if [ -n "$GHD_URL" ]; then
        info "Downloading ${GHD_URL##*/}"
        curl -fsSL -o "$TMP_DIR/github-desktop.deb" "$GHD_URL"
        sudo apt-get install -y "$TMP_DIR/github-desktop.deb"
    else
        warn "No GitHub Desktop .deb found for architecture '${DEB_ARCH}', skipping"
    fi
fi
ok "GitHub Desktop installed"
echo

echo -e "${BOLD}${GREEN}=== Desktop Applications Installation Complete ===${NC}"
