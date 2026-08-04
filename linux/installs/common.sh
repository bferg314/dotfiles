#!/usr/bin/env bash
# Shared helpers for the linux install scripts.
# Source this file, do not execute it:
#     . "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ─── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

step() { echo -e "${YELLOW}$1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}  ! $1${NC}"; }
info() { echo -e "${BLUE}  → $1${NC}"; }
die()  { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# ─── Distribution detection ───────────────────────────────────────────────────

# Sets PKG_MANAGER (pacman|dnf|apt) and DISTRO (arch|fedora|rhel|debian|ubuntu).
detect_distro() {
    if command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        DISTRO="arch"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        DISTRO="fedora"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                almalinux | rhel | rocky | centos) DISTRO="rhel" ;;
            esac
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        DISTRO="debian"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [ "$ID" = "ubuntu" ] || [[ "$ID_LIKE" == *ubuntu* ]]; then
                DISTRO="ubuntu"
            fi
        fi
    else
        die "Unable to detect package manager (pacman, dnf, or apt).
    Supported: Arch, Fedora, RHEL/AlmaLinux/Rocky, Ubuntu/Debian"
    fi

    echo -e "${BLUE}Detected package manager: ${BOLD}$PKG_MANAGER${NC}"
    echo -e "${BLUE}Distribution type: ${BOLD}$DISTRO${NC}"
    echo
}

# ─── Package manager wrappers ─────────────────────────────────────────────────
#
# These are functions rather than string variables on purpose. The old
# UPDATE_CMD="sudo dnf check-update || true" was expanded unquoted, so the shell
# passed "||" and "true" to dnf as package names instead of treating them as
# shell operators.

pkg_update() {
    case "$PKG_MANAGER" in
        pacman) sudo pacman -Sy ;;
        dnf)    sudo dnf check-update || true ;;  # 100 = updates available
        apt)    sudo apt-get update ;;
    esac
}

pkg_install() {
    case "$PKG_MANAGER" in
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
        apt)    sudo apt-get install -y "$@" ;;
    esac
}

# Install a group of development tools, whatever the distro calls it.
pkg_install_devtools() {
    case "$PKG_MANAGER" in
        pacman) sudo pacman -S --needed --noconfirm base-devel ;;
        dnf)
            if [ "$DISTRO" = "rhel" ]; then
                sudo dnf groupinstall -y "Development Tools"
            else
                sudo dnf install -y @development-tools
            fi
            ;;
        apt) sudo apt-get install -y build-essential ;;
    esac
}

# Add a .repo file by URL, handling both dnf4 and dnf5 syntax.
# dnf5 (Fedora 41+): config-manager addrepo --from-repofile=URL
# dnf4 (RHEL/Alma/Rocky): config-manager --add-repo URL
dnf_add_repo() {
    local url="$1"
    sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || true
    if sudo dnf config-manager addrepo --from-repofile="$url" 2>/dev/null; then
        return 0
    fi
    sudo dnf config-manager --add-repo "$url"
}

# ─── Temp files ───────────────────────────────────────────────────────────────

# Creates $TMP_DIR and removes it on exit. Downloads go here rather than into
# the current working directory.
make_tmpdir() {
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
}

# ─── Arch AUR helper ──────────────────────────────────────────────────────────

# Ensures an AUR helper exists and sets $AUR_HELPER.
# Bootstraps yay-bin from the AUR if neither yay nor paru is installed, so the
# AUR-only desktop apps no longer silently skip themselves.
ensure_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        warn "Cannot build an AUR helper as root (makepkg refuses to run as root)."
        warn "Run this script as a regular user with sudo access."
        return 1
    fi

    step "No AUR helper found. Building yay-bin from the AUR..."
    sudo pacman -S --needed --noconfirm base-devel git
    local build_dir
    build_dir="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
    (cd "$build_dir/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$build_dir"

    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
        ok "yay installed"
        return 0
    fi

    warn "Failed to install an AUR helper"
    return 1
}

# Install AUR packages, bootstrapping a helper if needed.
aur_install() {
    if ! ensure_aur_helper; then
        warn "Skipping AUR packages: $*"
        return 1
    fi
    "$AUR_HELPER" -S --needed --noconfirm "$@"
}

# ─── Flatpak ──────────────────────────────────────────────────────────────────

# Installs flatpak and adds the Flathub remote if missing.
ensure_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        step "Installing Flatpak..."
        pkg_install flatpak
    fi
    if ! flatpak remotes | grep -q flathub; then
        step "Adding Flathub repository..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

# ─── Misc ─────────────────────────────────────────────────────────────────────

# Machine architecture in the form used by most release tarballs.
# Echoes x86_64 / aarch64, or fails for anything else.
detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) return 1 ;;
    esac
}

# Latest release tag for a GitHub repo, e.g. github_latest_tag zellij-org/zellij
github_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
        grep '"tag_name"' | head -n1 | cut -d'"' -f4
}
