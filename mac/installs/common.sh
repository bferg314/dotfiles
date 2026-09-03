#!/usr/bin/env bash
# Shared helpers for the macOS install scripts and setup menu.
# Source this file, do not execute it:
#     . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
#
# The counterpart to linux/installs/common.sh. Same colors and same
# step/ok/warn/info/die vocabulary, so output reads identically on both
# platforms; the package-manager wrappers wrap brew instead of pacman/dnf/apt.
#
# macOS ships bash 3.2 and these run under it: no bash 4 features.

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

# ─── Homebrew ─────────────────────────────────────────────────────────────────

# Put brew on PATH for this script if it is installed but not yet exported --
# a fresh Apple Silicon install lands in /opt/homebrew, which is not on the
# default PATH until a login shell has re-read its profile.
brew_on_path() {
    command -v brew >/dev/null 2>&1 && return 0
    local prefix
    for prefix in /opt/homebrew /usr/local; do
        if [ -x "$prefix/bin/brew" ]; then
            eval "$("$prefix/bin/brew" shellenv)"
            return 0
        fi
    done
    return 1
}

# Install Homebrew if it is missing. Returns 1 rather than dying so a caller
# can decide whether it is fatal.
ensure_brew() {
    if brew_on_path; then
        ok "Homebrew already installed"
        return 0
    fi

    step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
        { warn "Homebrew install failed"; return 1; }

    brew_on_path || { warn "Homebrew is not on PATH after install"; return 1; }
    ok "Homebrew installed"
}

# The pkg_install equivalent. Idempotent, and a single failing formula does not
# abort the rest of the script the way a bare `brew install` under `set -e`
# would.
brew_install() {
    local formula
    for formula in "$@"; do
        if brew list --formula "$formula" >/dev/null 2>&1; then
            ok "$formula already installed"
        elif brew install "$formula"; then
            ok "$formula installed"
        else
            warn "$formula failed to install"
        fi
    done
}

# Casks are checked against /Applications as well: an app installed by hand
# before Homebrew existed on the machine is not in `brew list --cask`, and
# reinstalling over it is how you end up with two copies.
brew_cask() {
    local cask="$1" app="$2"
    if [ -n "$app" ] && [ -d "/Applications/$app" ]; then
        ok "$cask already installed (/Applications/$app)"
        return 0
    fi
    if brew list --cask "$cask" >/dev/null 2>&1; then
        ok "$cask already installed"
        return 0
    fi
    if brew install --cask "$cask"; then
        ok "$cask installed"
    else
        warn "$cask failed to install"
    fi
}

# ─── Tailscale ────────────────────────────────────────────────────────────────

# Echo the path to the tailscale CLI, or return 1 if it is not installed.
#
# The cask puts the binary in /usr/local/bin, which is not on PATH on an Apple
# Silicon machine whose Homebrew lives in /opt/homebrew, and an App Store
# install ships it inside the bundle instead. Check all three rather than
# reporting a working install as missing.
tailscale_bin() {
    local candidate
    if candidate="$(command -v tailscale 2>/dev/null)"; then
        printf '%s' "$candidate"
        return 0
    fi
    for candidate in /usr/local/bin/tailscale \
                     /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
        if [ -x "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# ─── Platform ─────────────────────────────────────────────────────────────────

# Machine architecture in the form used by most release tarballs.
detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) return 1 ;;
    esac
}

# Latest release tag for a GitHub repo, e.g. github_latest_tag charmbracelet/gum
github_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
        grep '"tag_name"' | head -n1 | cut -d'"' -f4
}

# ─── gum ──────────────────────────────────────────────────────────────────────

# gum draws the multi-select checklist in the setup menu. It is optional: the
# menu falls back to a numbered list when it is missing, so a failure here is a
# warning rather than fatal.
#
# Installed from the upstream GitHub release rather than the Homebrew formula,
# and pinned rather than latest: gum 2.0.0's migration to Bubble Tea v2 broke
# the Space key as a toggle in `gum choose --no-limit` -- confirmed on Linux by
# piping keys to it over a pty, `x` and `tab` still toggle a row, Space
# silently does nothing. The Homebrew formula carries the same broken release.
# 0.17.0 is the last release before that migration and does not have the bug.
# winget's charmbracelet.gum manifest has not picked up 2.0.0 yet, which is
# why this has only shown up on Linux and macOS so far. Revert GUM_PIN_TAG to
# `github_latest_tag charmbracelet/gum` and brew_install back to `brew_install
# gum` once upstream fixes it.
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

    # A previously brew-installed gum sits in /opt/homebrew/bin or
    # /usr/local/bin/gum -- ahead of, or the same as, where the pinned binary
    # below goes -- and would otherwise keep shadowing it on PATH.
    if brew_on_path && brew list --formula gum >/dev/null 2>&1; then
        brew uninstall gum >/dev/null 2>&1 || warn "Could not uninstall the Homebrew gum; it may still shadow the pinned binary"
    fi

    local arch
    arch="$(detect_arch)" || { warn "Unsupported architecture for the gum release: $(uname -m)"; return 1; }
    # The release assets say arm64 where uname says aarch64.
    [ "$arch" = "aarch64" ] && arch="arm64"

    local tag="$GUM_PIN_TAG" version="${GUM_PIN_TAG#v}"

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    if ! curl -fsSL "https://github.com/charmbracelet/gum/releases/download/${tag}/gum_${version}_Darwin_${arch}.tar.gz" |
            tar -xz -C "$tmp"; then
        warn "Failed to download or extract gum ${tag}"
        return 1
    fi

    local binary
    binary="$(find "$tmp" -type f -name gum -perm -u+x 2>/dev/null | head -n1)"
    [ -n "$binary" ] || { warn "No gum binary in the ${tag} archive"; return 1; }

    if sudo install -m 755 "$binary" /usr/local/bin/gum 2>/dev/null; then
        ok "gum installed ($tag) to /usr/local/bin"
        return 0
    fi

    mkdir -p "$HOME/.local/bin"
    install -m 755 "$binary" "$HOME/.local/bin/gum" || { warn "Could not install gum"; return 1; }
    ok "gum installed ($tag) to ~/.local/bin"

    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "$HOME/.local/bin is not on PATH, so the menu will not find gum until it is" ;;
    esac
}
