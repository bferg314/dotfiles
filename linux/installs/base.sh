#!/usr/bin/env bash
# Base installation script for all Linux devices
# Installs core development tools and utilities

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

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

# 3. Install zellij
step "Installing zellij..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install zellij
else
    ZELLIJ_ARCH="$(detect_arch)" || die "Unsupported architecture for the zellij binary release: $(uname -m)"
    ZELLIJ_VERSION="$(github_latest_tag zellij-org/zellij)"
    [ -n "$ZELLIJ_VERSION" ] || die "Could not determine the latest zellij release (GitHub API rate limit?)"
    info "Installing zellij ${ZELLIJ_VERSION} (${ZELLIJ_ARCH})"
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-${ZELLIJ_ARCH}-unknown-linux-musl.tar.gz" | tar -xz -C "$TMP_DIR"
    sudo install -m 755 "$TMP_DIR/zellij" /usr/local/bin/zellij
fi
ok "zellij installed"
echo

# 3b. Install the terminal font
# set -e is active, and a missing font should not abort the whole base install.
install_nerd_font FiraCode 'FiraCodeNerdFontMono-*.ttf' 'FiraCode Nerd Font Mono' || \
    warn "Continuing without the font; prompt glyphs will not render."
echo

# 4. Install Python and pip
#
# PYTHON_SERIES is the version this repo targets. Where a distro packages that
# series under a versioned name it is installed explicitly; otherwise the
# generic python3 goes in and the difference is reported rather than papered
# over. Arch tracks upstream closely enough that plain `python` is the target.
PYTHON_SERIES="3.14"

step "Installing Python ${PYTHON_SERIES} and pip..."
case "$PKG_MANAGER" in
    pacman)
        pkg_install python python-pip
        ;;
    dnf)
        if pkg_available "python${PYTHON_SERIES}"; then
            pkg_install "python${PYTHON_SERIES}" python3-pip
        else
            warn "python${PYTHON_SERIES} is not in this distro's repos - installing the default python3"
            pkg_install python3 python3-pip
        fi
        ;;
    apt)
        if pkg_available "python${PYTHON_SERIES}"; then
            # -venv is split out of the interpreter on Debian and Ubuntu, and
            # the alias-python.bashrc `cvenv` shortcut needs it.
            pkg_install "python${PYTHON_SERIES}" "python${PYTHON_SERIES}-venv" python3-pip
        else
            warn "python${PYTHON_SERIES} is not in this distro's repos - installing the default python3"
            pkg_install python3 python3-pip
        fi
        ;;
esac

DEFAULT_PYTHON="$(python3 --version 2>&1 | awk '{print $2}')"
if command -v "python${PYTHON_SERIES}" >/dev/null 2>&1; then
    ok "Python $("python${PYTHON_SERIES}" --version | awk '{print $2}') and pip installed"
    case "$DEFAULT_PYTHON" in
        "${PYTHON_SERIES}".*) ;;
        *) info "python3 still resolves to ${DEFAULT_PYTHON}; use python${PYTHON_SERIES} for new virtualenvs" ;;
    esac
else
    ok "Python ${DEFAULT_PYTHON} and pip installed"
    case "$DEFAULT_PYTHON" in
        "${PYTHON_SERIES}".*) ;;
        *) warn "This distro has no Python ${PYTHON_SERIES} package; ${DEFAULT_PYTHON} is the newest available" ;;
    esac
fi
echo

# 5. Install Node Version Manager (nvm) and LTS Node
step "Installing Node Version Manager (nvm)..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
    ok "nvm already installed"
fi

export NVM_DIR="$HOME/.nvm"
# nvm.sh returns non-zero in some paths; don't let errexit kill the script here
if [ -s "$NVM_DIR/nvm.sh" ]; then
    set +e
    \. "$NVM_DIR/nvm.sh"
    set -e
fi

if command -v nvm >/dev/null 2>&1; then
    step "Installing/updating Node.js LTS..."
    nvm install --lts
    nvm use --lts
    ok "Node.js LTS installed"
else
    warn "nvm did not load in this shell; open a new shell and run 'nvm install --lts'"
fi
echo

# 6. Install Development Tools
step "Installing development tools..."
pkg_install_devtools
ok "Development tools installed"
echo

# 6b. Install the Rust toolchain
# After the development tools above: the default toolchain links with cc, and
# rustup only warns about a missing linker rather than failing.
# set -e is active, and a failed rustup should not abort the whole base install.
step "Installing rustup..."
install_rustup || warn "Continuing without Rust; re-run this script or see https://rustup.rs"
echo

# 7. Install and configure Git
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

# 8. Install GitHub CLI
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

echo -e "${BOLD}${GREEN}=== Base Tools Installation Complete ===${NC}"
echo
echo -e "${YELLOW}IMPORTANT: If this is your first time installing Docker, you need to"
echo -e "log out and log back in for the docker group changes to take effect.${NC}"
echo
echo -e "${BLUE}Authenticate the GitHub CLI when you are ready: ${BOLD}gh auth login${NC}"
echo -e "${BLUE}cargo and rustc land on PATH in a new shell (bashrc.d/rust.bashrc): ${BOLD}rustup show${NC}"
