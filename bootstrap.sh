#!/usr/bin/env bash
# bootstrap.sh - Day-zero machine setup
# Installs git & vim, clones dotfiles, configures git identity,
# generates an SSH key for GitHub, and sets up authorized_keys.
#
# Usage:
#   bash <(wget -qO- https://raw.githubusercontent.com/USER/dotfiles/master/bootstrap.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/USER/dotfiles/master/bootstrap.sh)

DOTFILES_DIR="$HOME/dotfiles"

# Color definitions (matches base.sh / server.sh / desktop.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────

print_header() {
    echo
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║         Dotfiles Bootstrap Setup           ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
}

step()  { echo -e "${BOLD}${BLUE}[Step $1]${NC} ${BOLD}$2${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ! $1${NC}"; }
info()  { echo -e "${BLUE}  → $1${NC}"; }
sep()   { echo; echo -e "${CYAN}────────────────────────────────────────────${NC}"; echo; }

# ─── Step 1: Detect package manager ──────────────────────────────────────────

detect_package_manager() {
    step "1" "Detecting package manager"

    if command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        DISTRO="arch"
        INSTALL_CMD="sudo pacman -S --noconfirm"
        UPDATE_CMD="sudo pacman -Sy"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
        UPDATE_CMD="sudo dnf check-update || true"

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
        echo -e "${RED}  ✗ No supported package manager found (pacman / dnf / apt-get)${NC}"
        echo -e "${RED}    Supported: Arch Linux, Fedora, RHEL/AlmaLinux/Rocky, Ubuntu/Debian${NC}"
        exit 1
    fi

    ok "Package manager: ${BOLD}${PKG_MANAGER}${NC}"
    [ "$PKG_MANAGER" = "dnf" ] && ok "Distribution:    ${BOLD}${DISTRO}${NC}"
    sep
}

# ─── Step 2: Install git and vim ─────────────────────────────────────────────

install_prerequisites() {
    step "2" "Installing git and vim"

    info "Refreshing package lists..."
    $UPDATE_CMD

    if command -v git >/dev/null 2>&1; then
        ok "git already installed ($(git --version))"
    else
        info "Installing git..."
        $INSTALL_CMD git
        ok "git installed"
    fi

    if command -v vim >/dev/null 2>&1; then
        ok "vim already installed"
    else
        info "Installing vim..."
        if [ "$PKG_MANAGER" = "dnf" ]; then
            $INSTALL_CMD vim-enhanced
        else
            $INSTALL_CMD vim
        fi
        ok "vim installed"
    fi

    sep
}

# ─── Step 3: Clone dotfiles repo ─────────────────────────────────────────────

clone_dotfiles() {
    step "3" "Cloning dotfiles repository"

    echo
    read -p "$(echo -e "${CYAN}  GitHub username: ${NC}")" GH_USER
    if [ -z "$GH_USER" ]; then
        warn "No username entered, skipping clone"
        sep
        return 0
    fi

    read -p "$(echo -e "${CYAN}  Repo name [dotfiles]: ${NC}")" REPO_NAME
    REPO_NAME="${REPO_NAME:-dotfiles}"

    local REPO_URL="https://github.com/${GH_USER}/${REPO_NAME}.git"
    info "Repo: ${REPO_URL}"
    echo

    if [ -d "${DOTFILES_DIR}/.git" ]; then
        local existing_remote
        existing_remote=$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || echo "")
        if [[ "$existing_remote" == *"${GH_USER}/${REPO_NAME}"* ]]; then
            ok "Dotfiles already cloned at ${DOTFILES_DIR}"
            info "Pulling latest changes..."
            git -C "$DOTFILES_DIR" pull --ff-only || warn "Pull failed (local changes?), continuing"
        else
            warn "Directory ${DOTFILES_DIR} exists but points to a different remote:"
            warn "  Found:    ${existing_remote}"
            warn "  Expected: ${REPO_URL}"
            warn "Skipping clone. Remove ${DOTFILES_DIR} manually for a fresh clone."
        fi
    elif [ -d "$DOTFILES_DIR" ]; then
        warn "Directory ${DOTFILES_DIR} exists but is not a git repository."
        warn "Skipping clone. Remove it manually if you want to clone here."
    else
        info "Cloning into ${DOTFILES_DIR}..."
        git clone "$REPO_URL" "$DOTFILES_DIR"
        ok "Dotfiles cloned to ${DOTFILES_DIR}"
    fi

    sep
}

# ─── Step 4: Configure git global identity ───────────────────────────────────

configure_git() {
    step "4" "Configuring git global identity"

    if [ -n "$(git config --global user.name 2>/dev/null)" ]; then
        ok "Git name already set: $(git config --global user.name)"
    else
        read -p "$(echo -e "${CYAN}  Enter your Git name:  ${NC}")" git_name
        if [ -n "$git_name" ]; then
            git config --global user.name "$git_name"
            ok "Git name set to: $git_name"
        else
            warn "No name entered, skipping git user.name"
        fi
    fi

    if [ -n "$(git config --global user.email 2>/dev/null)" ]; then
        ok "Git email already set: $(git config --global user.email)"
    else
        read -p "$(echo -e "${CYAN}  Enter your Git email: ${NC}")" git_email
        if [ -n "$git_email" ]; then
            git config --global user.email "$git_email"
            ok "Git email set to: $git_email"
        else
            warn "No email entered, skipping git user.email"
        fi
    fi

    sep
}

# ─── Step 5: Generate ed25519 SSH key for GitHub ─────────────────────────────

generate_ssh_key() {
    step "5" "Generating SSH key for GitHub"

    local key_path="$HOME/.ssh/id_ed25519"
    local pub_path="${key_path}.pub"

    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        info "Created ~/.ssh with permissions 700"
    fi

    if [ -f "$key_path" ]; then
        ok "SSH key already exists at ${key_path}"
    else
        echo
        read -p "$(echo -e "${CYAN}  Protect SSH key with a passphrase? (recommended) [Y/n]: ${NC}")" use_passphrase
        echo
        if [[ "$use_passphrase" =~ ^[Nn]$ ]]; then
            ssh-keygen -t ed25519 -f "$key_path" -N "" -C "${USER}@$(hostname)"
        else
            ssh-keygen -t ed25519 -f "$key_path" -C "${USER}@$(hostname)"
        fi
        chmod 600 "$key_path"
        ok "SSH key generated at ${key_path}"
    fi

    echo
    echo -e "${BOLD}${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║  Copy this public key and add it to GitHub:                    ║${NC}"
    echo -e "${BOLD}${YELLOW}║  https://github.com/settings/ssh/new                          ║${NC}"
    echo -e "${BOLD}${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BOLD}${GREEN}$(cat "$pub_path")${NC}"
    echo
    read -p "$(echo -e "${CYAN}  Press Enter once you have added the key to GitHub...${NC}")"

    sep
}

# ─── Step 6: Add authorized_keys entry for remote SSH login ──────────────────

setup_authorized_keys() {
    step "6" "Setting up authorized_keys for remote login"

    local ssh_dir="$HOME/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"

    if [ ! -d "$ssh_dir" ]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        info "Created ~/.ssh with permissions 700"
    fi

    echo
    echo -e "${CYAN}  Paste the public SSH key from the machine you will remote in from.${NC}"
    echo -e "${CYAN}  (e.g., from your local ~/.ssh/id_*.pub)${NC}"
    echo -e "${CYAN}  Press Enter to skip.${NC}"
    echo
    read -p "$(echo -e "${BOLD}  Paste public key: ${NC}")" pasted_key

    if [ -z "$pasted_key" ]; then
        warn "No key entered, skipping authorized_keys setup"
        sep
        return 0
    fi

    if ! echo "$pasted_key" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) '; then
        warn "Input does not look like a valid SSH public key (expected: ssh-ed25519 / ssh-rsa / ecdsa-sha2-*)"
        warn "Skipping. Add it manually to ~/.ssh/authorized_keys if needed."
        sep
        return 0
    fi

    if [ -f "$auth_keys" ] && grep -qF "$pasted_key" "$auth_keys"; then
        ok "Key already present in ${auth_keys}"
    else
        echo "$pasted_key" >> "$auth_keys"
        chmod 600 "$auth_keys"
        ok "Key added to ${auth_keys} (permissions: 600)"
    fi

    sep
}

# ─── Step 7: Offer full dotfiles setup ───────────────────────────────────────

offer_dotfiles_setup() {
    step "7" "Full dotfiles setup (optional)"

    local setup_script="${DOTFILES_DIR}/linux/setup.sh"

    if [ ! -f "$setup_script" ]; then
        warn "setup.sh not found at ${setup_script}"
        warn "Ensure the repo was cloned successfully in step 3."
        sep
        return 0
    fi

    echo
    read -p "$(echo -e "${CYAN}  Run linux/setup.sh now for full dotfiles setup? [y/N]: ${NC}")" run_setup
    echo

    if [[ "$run_setup" =~ ^[Yy]$ ]]; then
        info "Launching ${setup_script}..."
        echo
        bash "$setup_script"
    else
        info "Skipped. Run it later with:"
        info "  bash ${setup_script}"
    fi

    sep
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    print_header

    detect_package_manager   # Step 1
    install_prerequisites    # Step 2
    clone_dotfiles           # Step 3
    configure_git            # Step 4
    generate_ssh_key         # Step 5
    setup_authorized_keys    # Step 6
    offer_dotfiles_setup     # Step 7

    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║           Bootstrap Complete!              ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}  Summary:${NC}"
    echo -e "  ${BOLD}Dotfiles:${NC}     ${DOTFILES_DIR}"
    echo -e "  ${BOLD}Git identity:${NC} $(git config --global user.name 2>/dev/null || echo '(not set)') <$(git config --global user.email 2>/dev/null || echo 'not set')>"
    echo -e "  ${BOLD}SSH key:${NC}      ${HOME}/.ssh/id_ed25519.pub"
    echo -e "  ${BOLD}Auth keys:${NC}    ${HOME}/.ssh/authorized_keys"
    echo
    echo -e "${YELLOW}  Next steps:${NC}"
    echo -e "  1. Verify GitHub SSH auth: ${BOLD}ssh -T git@github.com${NC}"
    echo -e "  2. Run dotfiles setup:     ${BOLD}bash ${DOTFILES_DIR}/linux/setup.sh${NC}"
    echo
}

main "$@"
