#!/usr/bin/env bash
# Base installation script for all Linux devices
# Installs core development tools and utilities

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# setup.sh exports REPO_ROOT; work it out when this is run on its own.
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=lib/shared.sh
. "$REPO_ROOT/lib/shared.sh"

echo -e "${BOLD}${CYAN}=== Base Tools Installation ===${NC}"
echo

detect_distro
make_tmpdir

# Clean up any stale/conflicting Docker repo and keyring files before update
if [ "$PKG_MANAGER" = "apt" ]; then
    for f in /etc/apt/sources.list.d/docker.list /etc/apt/sources.list.d/docker.sources; do
        [ -f "$f" ] && sudo rm "$f" && echo -e "${YELLOW}Removed stale Docker repo: $f${NC}"
    done
    for k in /usr/share/keyrings/docker-archive-keyring.gpg /etc/apt/keyrings/docker.asc /etc/apt/keyrings/docker.gpg; do
        [ -f "$k" ] && sudo rm "$k" && echo -e "${YELLOW}Removed stale Docker keyring: $k${NC}"
    done
fi

# Update package lists
step "Updating package lists..."
pkg_update
echo

# 1. Install Vim
step "Installing vim..."
if [ "$PKG_MANAGER" = "dnf" ]; then
    pkg_install vim-enhanced  # Enhanced vim without GUI dependencies
else
    pkg_install vim
fi
ok "Vim installed"

# Neovim reads the same vimrc (shared/nvim/init.vim). Optional: the RHEL family
# only carries it in EPEL, so skip it where the repos do not have it.
if command -v nvim >/dev/null 2>&1; then
    ok "Neovim already installed"
elif pkg_available neovim; then
    pkg_install neovim && ok "Neovim installed"
else
    info "Neovim is not in this distro's repos (enable EPEL on RHEL-family systems); skipping"
fi
echo

# 2. Install Docker
step "Installing Docker..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install docker docker-compose docker-buildx
elif [ "$PKG_MANAGER" = "dnf" ]; then
    if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
        if [ "$DISTRO" = "rhel" ]; then
            # AlmaLinux/RHEL use a different Docker repository
            dnf_add_repo https://download.docker.com/linux/rhel/docker-ce.repo
        else
            dnf_add_repo https://download.docker.com/linux/fedora/docker-ce.repo
        fi
    else
        info "Docker repository already configured"
    fi
    pkg_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
elif [ "$PKG_MANAGER" = "apt" ]; then
    pkg_install apt-transport-https ca-certificates curl gnupg lsb-release
    # Docker publishes separate repos for debian and ubuntu
    DOCKER_DISTRO="debian"
    [ "$DISTRO" = "ubuntu" ] && DOCKER_DISTRO="ubuntu"
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    pkg_update
    pkg_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$USER"
    ok "Docker installed and user added to docker group"
    echo -e "${YELLOW}  NOTE: You need to log out and back in for docker group changes to take effect${NC}"
else
    ok "Docker installed (user already in docker group)"
fi
echo

# 3. Install zellij (checksum-verified release binary; Arch's own package)
step "Installing zellij..."
install_zellij || warn "Continuing without zellij; re-run this script to retry."
echo

# 3a. Install gum, which draws the setup menu's checklist.
# set -e is active, and the menu works without it, so a failure only warns.
ensure_gum || warn "Continuing without gum; the setup menu will use its numbered fallback."
echo

# 3b. Install the terminal font
# set -e is active, and a missing font should not abort the whole base install.
install_nerd_font FiraCode 'FiraCodeNerdFontMono-*.ttf' 'FiraCode Nerd Font Mono' || \
    warn "Continuing without the font; prompt glyphs will not render."
echo

# 4. System Python
#
# Only the distro's own python3, for the distro's tools and for scripts that
# expect /usr/bin/python3. The Python you develop with is mise's (pinned in
# shared/mise/config.toml), which is the same version on every distro -- no
# more checking whether this one packages python3.14.
step "Installing system python3..."
case "$PKG_MANAGER" in
    pacman) pkg_install python ;;
    *)      pkg_install python3 ;;
esac
ok "System python3 installed ($(python3 --version 2>&1 | awk '{print $2}'))"
echo

# 5. Install Development Tools
step "Installing development tools..."
pkg_install_devtools
ok "Development tools installed"
echo

# 5b. Install the Rust toolchain
# After the development tools above: the default toolchain links with cc, and
# rustup only warns about a missing linker rather than failing.
# set -e is active, and a failed rustup should not abort the whole base install.
step "Installing rustup..."
install_rustup || warn "Continuing without Rust; re-run this script or see https://rustup.rs"
echo

# 5c. Install mise, then everything in shared/mise/config.toml: node, python,
# go, uv, ruff, and the CLI tools distros do not package (starship, fzf, eza,
# bat, delta, lazygit, atuin). Replaces the old nvm, distro python3.14 and
# /usr/local/go installs.
# set -e is active, and a failed tool should not abort the whole base install.
step "Installing mise..."
if install_mise; then
    mise_install_tools || warn "Re-run 'mise install' in a new shell to finish."
    # Go tools that only ship as source (folgit, ...), through gup -- see
    # shared/gup/README.md. Needs mise's go, so it comes after the line above.
    go_tools_install || true
else
    warn "Continuing without mise; see https://mise.jdx.dev/installing-mise.html"
fi
echo

# 6. Install and configure Git
step "Installing git..."
pkg_install git
ok "Git installed"
echo

# Configure git if not already configured
if [ -z "$(git config --global user.name)" ]; then
    read -r -p "$(echo -e "${CYAN}Enter your Git name: ${NC}")" git_name
    [ -n "$git_name" ] && git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    read -r -p "$(echo -e "${CYAN}Enter your Git email: ${NC}")" git_email
    [ -n "$git_email" ] && git config --global user.email "$git_email"
fi

echo -e "${BLUE}Git configured with:${NC}"
echo -e "  ${BOLD}Name:${NC} $(git config --global user.name)"
echo -e "  ${BOLD}Email:${NC} $(git config --global user.email)"
echo

# 7. Install GitHub CLI
step "Installing GitHub CLI..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install github-cli
elif [ "$PKG_MANAGER" = "dnf" ]; then
    # GitHub's own repo carries current versions for both Fedora and RHEL-based
    if [ ! -f /etc/yum.repos.d/gh-cli.repo ]; then
        dnf_add_repo https://cli.github.com/packages/rpm/gh-cli.repo
    else
        info "GitHub CLI repository already configured"
    fi
    pkg_install gh
elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    # This file is already a binary keyring, so it does not need --dearmor
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    pkg_update
    pkg_install gh
fi
ok "GitHub CLI installed ($(gh --version 2>/dev/null | head -n1))"
echo

# 8. Install yazi (TUI file manager)
#
# Arch packages it directly. Fedora and the RHEL family get it from the
# lihaohong/yazi COPR, which also targets EL9+ chroots. Debian and Ubuntu get
# it from yazi's own apt repo, the same shape as the GitHub CLI repo above --
# none of the four carry a current yazi in their own repos yet.
step "Installing yazi..."
if command -v yazi >/dev/null 2>&1; then
    info "yazi already installed"
elif [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install yazi
elif [ "$PKG_MANAGER" = "dnf" ]; then
    sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || true
    sudo dnf -y copr enable lihaohong/yazi
    pkg_install yazi
elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg |
        sudo tee /usr/share/keyrings/yazi-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main" |
        sudo tee /etc/apt/sources.list.d/yazi.list > /dev/null
    pkg_update
    pkg_install yazi
fi
ok "yazi installed ($(yazi --version 2>/dev/null || echo 'version unknown'))"

# 8b. Install yazi's preview and navigation extras.
#
# Best-effort and per-package: yazi itself is fully usable without any of
# these, they just turn on richer previews (video, archives, PDF, images) and
# the fd/rg jump integrations; fzf and zoxide come from mise (5c above), which
# keeps them current where distros lag. Package availability varies a lot
# across the four families, so each is checked with pkg_available first
# rather than batching them into one command that a single missing name would
# fail entirely (pacman is the exception: yazi's own docs list these names as
# available in Arch's official repos).
step "Installing yazi preview/navigation extras..."
case "$PKG_MANAGER" in
    pacman)
        pkg_install ffmpeg 7zip jq poppler fd ripgrep resvg imagemagick
        ;;
    dnf | apt)
        YAZI_EXTRAS=""
        _want() { pkg_available "$1" && YAZI_EXTRAS="$YAZI_EXTRAS $1"; }
        # Every call is `|| true`: pkg_available returning false for an
        # optional extra must not trip `set -e` and abort the whole install.
        if [ "$PKG_MANAGER" = "dnf" ]; then
            { _want 7zip || _want p7zip; } || true
            _want jq || true
            _want poppler-utils || true
            _want fd-find || true
            _want ripgrep || true
            { _want ffmpeg || _want ffmpeg-free; } || true
            _want ImageMagick || true
        else
            { _want 7zip || _want p7zip-full; } || true
            _want jq || true
            _want poppler-utils || true
            _want fd-find || true
            _want ripgrep || true
            _want ffmpeg || true
            _want imagemagick || true
        fi
        if [ -n "$YAZI_EXTRAS" ]; then
            # shellcheck disable=SC2086
            pkg_install $YAZI_EXTRAS || warn "Some yazi extras failed to install; yazi itself is unaffected"
        else
            warn "None of yazi's preview extras are in this distro's repos"
        fi
        # Debian/Ubuntu's fd-find installs the binary as `fdfind` to avoid a
        # name clash with an unrelated package; symlink it to `fd` so yazi
        # (and everything else expecting `fd`) can find it.
        if [ "$PKG_MANAGER" = "apt" ] && command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
            sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        fi
        ;;
esac
ok "yazi extras installed"
echo

# 9. delta is installed by mise above; now that it exists, make it git's pager.
dot_git_delta_include || true
echo

echo -e "${BOLD}${GREEN}=== Base Tools Installation Complete ===${NC}"
echo
echo -e "${YELLOW}IMPORTANT: If this is your first time installing Docker, you need to"
echo -e "log out and log back in for the docker group changes to take effect.${NC}"
echo
echo -e "${BLUE}Open a new shell to pick up mise, starship, zoxide, fzf and atuin.${NC}"
echo -e "${BLUE}Authenticate the GitHub CLI when you are ready: ${BOLD}gh auth login${NC}"
echo -e "${BLUE}Check what mise manages: ${BOLD}mise ls${NC}${BLUE}   Rust: ${BOLD}rustup show${NC}"
