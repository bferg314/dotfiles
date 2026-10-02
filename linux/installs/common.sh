#!/usr/bin/env bash
# Shared helpers for the linux install scripts.
# Source this file, do not execute it:
#     . "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ─── Colors ───────────────────────────────────────────────────────────────────

# Used by the scripts that source this file, not by this file itself.
# shellcheck disable=SC2034
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

# GitHub API (with your token when one is available) and SHA-256 checks.
# shellcheck source=lib/download.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/download.sh"

# ─── Distribution detection ───────────────────────────────────────────────────

# Sets PKG_MANAGER (pacman|dnf|apt) and DISTRO (arch|fedora|rhel|debian|ubuntu).
# Returns 1 on an unsupported platform without printing or exiting: the setup
# menu wants these values for its header but must stay up without them, while
# the installers below still treat the same condition as fatal.
detect_distro_quiet() {
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
        return 1
    fi
}

detect_distro() {
    detect_distro_quiet || die "Unable to detect package manager (pacman, dnf, or apt).
    Supported: Arch, Fedora, RHEL/AlmaLinux/Rocky, Ubuntu/Debian"

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

# True when the package manager knows a package name. Used to try a
# version-pinned name (python3.14) before falling back to the generic one,
# rather than letting the install fail on distros that do not carry it.
pkg_available() {
    case "$PKG_MANAGER" in
        pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
        dnf)    dnf list "$1" >/dev/null 2>&1 ;;
        apt)    apt-cache show "$1" >/dev/null 2>&1 ;;
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

# ─── Rust ─────────────────────────────────────────────────────────────────────

# Install rustup from the upstream installer, and put cargo on PATH for the
# rest of this script.
#
# Upstream rather than the distro package: only Arch carries a current `rustup`,
# while Debian and the RHEL family ship a pinned `rustc` with no toolchain
# management at all. One source also means Linux, macOS and Windows all end up
# on the same rustup.
#
# --no-modify-path, because rustup would otherwise append its own PATH line to
# ~/.bashrc, ~/.profile and ~/.zshenv. bashrc.d/rust.bashrc does that instead,
# so the shell config stays in the repo.
install_rustup() {
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    fi

    if command -v rustup >/dev/null 2>&1; then
        ok "rustup already installed ($(rustup --version 2>/dev/null | head -n1))"
        rustup update || warn "rustup update failed; the existing toolchain is unchanged"
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
        sh -s -- -y --no-modify-path --default-toolchain stable ||
        { warn "rustup install failed"; return 1; }

    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    fi

    command -v rustup >/dev/null 2>&1 || { warn "rustup is not on PATH after install"; return 1; }
    ok "rustup installed ($(rustup --version 2>/dev/null | head -n1))"
}

# ─── mise ─────────────────────────────────────────────────────────────────────

# Install mise to ~/.local/bin with its official installer, which picks the
# right build for this machine and verifies its checksum before installing.
# mise then installs node, python, go, uv, ruff and -- on Linux -- the CLI
# tools distros do not package (see shared/mise/config.toml).
#
# Per-user rather than a distro package: only some distros carry mise, and the
# per-user binary can update itself (`mise self-update`) without sudo.
install_mise() {
    local mise="$HOME/.local/bin/mise"

    if [ -x "$mise" ] || command -v mise >/dev/null 2>&1; then
        command -v mise >/dev/null 2>&1 && mise="$(command -v mise)"
        ok "mise already installed ($("$mise" --version 2>/dev/null | awk '{print $1}'))"
        "$mise" self-update --yes >/dev/null 2>&1 || true
    else
        # Retried, because everything after this depends on it: one reset
        # connection while the installer fetches mise's release index would
        # otherwise leave the whole toolchain uninstalled. That failure happens
        # inside the installer's own download, so curl's --retry cannot help.
        #
        # The installer is downloaded first rather than piped: in `curl | sh`
        # the status is sh's, and sh runs an empty script happily when curl
        # fails. Success is judged by the binary actually being there.
        local attempt script
        for attempt in 1 2 3; do
            if script="$(curl -fsSL https://mise.run)" &&
                printf '%s\n' "$script" | MISE_QUIET=1 sh && [ -x "$mise" ]; then
                break
            fi
            [ "$attempt" = 3 ] && { warn "mise install failed after 3 attempts"; return 1; }
            warn "mise install failed (attempt $attempt of 3); retrying in $((attempt * 5))s"
            sleep $((attempt * 5))
        done
        ok "mise installed ($("$mise" --version 2>/dev/null | awk '{print $1}'))"
    fi

    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
}

# ─── zellij ───────────────────────────────────────────────────────────────────

# Install the latest zellij release binary to /usr/local/bin. Arch packages it;
# nothing else does, so everyone else gets upstream's static musl build.
#
# zellij publishes the checksum of the extracted binary rather than of the
# tarball, so the check runs after extraction and before install.
install_zellij() {
    if [ "$PKG_MANAGER" = "pacman" ]; then
        pkg_install zellij
        return
    fi

    local arch tag installed
    arch="$(detect_arch)" || { warn "Unsupported architecture for the zellij binary release: $(uname -m)"; return 1; }
    tag="$(github_latest_tag zellij-org/zellij)"
    [ -n "$tag" ] || { warn "Could not determine the latest zellij release (GitHub API unreachable?)"; return 1; }

    if command -v zellij >/dev/null 2>&1; then
        installed="v$(zellij --version 2>/dev/null | awk '{print $2}')"
        if [ "$installed" = "$tag" ]; then
            ok "zellij already installed ($tag)"
            return 0
        fi
    fi
    info "Installing zellij ${tag} (${arch})"

    local tmp base expected
    tmp="$(mktemp -d)"
    # Local trap: the caller's make_tmpdir trap must survive this function.
    trap 'rm -rf "$tmp"' RETURN

    base="https://github.com/zellij-org/zellij/releases/download/${tag}/zellij-${arch}-unknown-linux-musl"
    curl -fsSL "${base}.tar.gz" -o "$tmp/zellij.tar.gz" || { warn "Failed to download zellij ${tag}"; return 1; }
    tar -xzf "$tmp/zellij.tar.gz" -C "$tmp" || { warn "Failed to extract zellij ${tag}"; return 1; }
    expected="$(curl -fsSL "${base}.sha256sum" | awk '{print $1}')"
    verify_sha256 "$tmp/zellij" "$expected" || return 1

    sudo install -m 755 "$tmp/zellij" /usr/local/bin/zellij
    ok "zellij installed ($tag)"
}

# ─── gum ──────────────────────────────────────────────────────────────────────

# gum draws the multi-select checklist in the setup menu. It is optional: the
# menu falls back to a numbered list when it is missing, so a failure here is a
# warning rather than fatal.
#
# Installed per-user into ~/.local/bin from the upstream release, the same way
# zellij and the Nerd Font are, so every platform ends up on one source.
#
# Pinned rather than "latest", and Arch's own package (which carries the same
# release) is bypassed too: gum 2.0.0's migration to Bubble Tea v2 broke the
# Space key as a toggle in `gum choose --no-limit` -- confirmed by piping keys
# to it over a pty, `x` and `tab` still toggle a row, Space silently does
# nothing. 0.17.0 is the last release before that migration and does not have
# the bug. winget's charmbracelet.gum manifest has not picked up 2.0.0 yet,
# which is why this has only shown up on Linux and macOS so far. Revert
# GUM_PIN_TAG to `github_latest_tag charmbracelet/gum` once upstream fixes it.
ensure_gum() {
    step "Installing gum..."

    local GUM_PIN_TAG="v0.17.0"

    if command -v gum >/dev/null 2>&1; then
        if [ "$(gum --version 2>/dev/null | awk '{print $3}')" = "$GUM_PIN_TAG" ]; then
            ok "gum already installed ($GUM_PIN_TAG)"
            return 0
        fi
        info "Replacing gum with the pinned $GUM_PIN_TAG (see the comment above ensure_gum)"
    fi

    local arch
    arch="$(detect_arch)" || { warn "Unsupported architecture for the gum release: $(uname -m)"; return 1; }
    # The release assets say arm64 where uname says aarch64.
    [ "$arch" = "aarch64" ] && arch="arm64"

    local tag version
    tag="$GUM_PIN_TAG"
    version="${tag#v}"

    local tmp
    tmp="$(mktemp -d)"
    # Local trap: the caller's make_tmpdir trap must survive this function.
    trap 'rm -rf "$tmp"' RETURN

    local release="https://github.com/charmbracelet/gum/releases/download/${tag}"
    local asset="gum_${version}_Linux_${arch}.tar.gz"
    curl -fsSL "$release/$asset" -o "$tmp/$asset" || { warn "Failed to download gum ${tag}"; return 1; }
    verify_sha256 "$tmp/$asset" "$(checksum_from_list "$release/checksums.txt" "$asset")" || return 1
    tar -xzf "$tmp/$asset" -C "$tmp" || { warn "Failed to extract gum ${tag}"; return 1; }

    # Older releases put the binary at the archive root, newer ones inside a
    # versioned directory.
    local binary
    binary="$(find "$tmp" -type f -name gum -perm -u+x 2>/dev/null | head -n1)"
    [ -n "$binary" ] || { warn "No gum binary in the ${tag} archive"; return 1; }

    # /usr/local/bin, the same place the zellij release binary goes in base.sh.
    # It is on PATH on every supported distro, which ~/.local/bin is not --
    # nothing in this repo puts that on PATH, so installing there produced a gum
    # that was present and unfindable, and a menu that silently kept using its
    # numbered fallback.
    if sudo install -m 755 "$binary" /usr/local/bin/gum 2>/dev/null; then
        ok "gum installed ($tag) to /usr/local/bin"
        return 0
    fi

    # No sudo: fall back to a per-user install and say what that costs, rather
    # than leaving the machine with no gum at all.
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$binary" "$HOME/.local/bin/gum" || { warn "Could not install gum"; return 1; }
    ok "gum installed ($tag) to ~/.local/bin"

    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "$HOME/.local/bin is not on PATH, so the menu will not find gum until it is" ;;
    esac
}

# ─── Fonts ────────────────────────────────────────────────────────────────────

# Install a Nerd Font from the upstream GitHub release, per-user.
#     install_nerd_font <archive> <file glob> <display name>
#     install_nerd_font FiraCode 'FiraCodeNerdFontMono-*.ttf' 'FiraCode Nerd Font Mono'
#
# The Nerd Font variants are not packaged consistently across distros (Arch has
# ttf-firacode-nerd, Fedora and Debian have only the non-Nerd Fira Code), so
# this pulls the release directly the way the zellij install in base.sh does.
# Same source on every platform means every machine gets the same version.
install_nerd_font() {
    local archive="$1" pattern="$2" name="$3"
    local font_dir="$HOME/.local/share/fonts/$archive"

    step "Installing $name..."

    # shellcheck disable=SC2086
    if [ -d "$font_dir" ] && ls $font_dir/$pattern >/dev/null 2>&1; then
        ok "$name already installed"
        return 0
    fi

    local tag
    tag="$(github_latest_tag ryanoasis/nerd-fonts)"
    [ -n "$tag" ] || { warn "Could not determine the latest nerd-fonts release (GitHub API rate limit?)"; return 1; }
    info "nerd-fonts $tag"

    local tmp
    tmp="$(mktemp -d)"
    # Local trap: the caller's make_tmpdir trap must survive this function.
    trap 'rm -rf "$tmp"' RETURN

    local release="https://github.com/ryanoasis/nerd-fonts/releases/download/${tag}"
    curl -fsSL "$release/${archive}.tar.xz" -o "$tmp/${archive}.tar.xz" ||
        { warn "Failed to download ${archive}.tar.xz"; return 1; }
    verify_sha256 "$tmp/${archive}.tar.xz" "$(checksum_from_list "$release/SHA-256.txt" "${archive}.tar.xz")" || return 1
    tar -xJf "$tmp/${archive}.tar.xz" -C "$tmp" || { warn "Failed to extract ${archive}.tar.xz"; return 1; }

    mkdir -p "$font_dir"
    # Only the requested variant: the archive also carries the proportional and
    # non-Mono families, which we do not want cluttering the font list.
    # shellcheck disable=SC2086
    cp $tmp/$pattern "$font_dir/" 2>/dev/null || {
        warn "No files matching $pattern in ${archive}.tar.xz"
        return 1
    }

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null
    else
        warn "fc-cache not found; the font may not appear until you log out and back in"
    fi

    ok "$name installed"
}
