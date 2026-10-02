#!/usr/bin/env bash
# Base installation script for macOS
# Installs core development tools and utilities
#
# What Homebrew installs is listed in mac/Brewfile; this script installs
# Homebrew itself, runs `brew bundle`, and handles the few things that do not
# come from Homebrew (Command Line Tools, the font, gum, rustup, mise's tools).

set -e  # Exit on error

# Colors and the step/ok/warn/info/die helpers, shared with setup.sh and the
# other installers rather than redeclared here.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# setup.sh exports REPO_ROOT; work it out when this is run on its own.
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck source=lib/shared.sh
. "$REPO_ROOT/lib/shared.sh"

echo -e "${BOLD}${CYAN}=== Base Tools Installation (macOS) ===${NC}"
echo

# 1. Xcode Command Line Tools -- git, cc and make, which Homebrew and the Rust
# toolchain both need. The installer is a GUI dialog, so this stops and asks
# for a re-run rather than waiting on it.
step "Checking Xcode Command Line Tools..."
if ! xcode-select -p >/dev/null 2>&1; then
    step "Installing Xcode Command Line Tools..."
    xcode-select --install
    warn "Finish the Command Line Tools install in the dialog, then run this script again."
    exit 0
fi
ok "Xcode Command Line Tools already installed"
echo

# 2. Homebrew
ensure_brew || die "Homebrew is required for the rest of this script."

# Put brew on PATH for new login shells on Apple Silicon, where it lives in
# /opt/homebrew. Intel Macs use /usr/local, which is already on PATH.
if [ "$(uname -m)" = "arm64" ] && ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
    # shellcheck disable=SC2016  # written literally into .zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    ok "Added Homebrew to ~/.zprofile"
fi

step "Updating Homebrew..."
brew update
echo

# 3. Everything in the Brewfile. `brew bundle` keeps going past a formula that
# fails and reports it at the end, so one bad formula does not stop the rest;
# a failure here is a warning, not fatal, for the same reason.
step "Installing packages from mac/Brewfile..."
if brew bundle --file="$REPO_ROOT/mac/Brewfile"; then
    ok "Brewfile packages installed"
else
    warn "Some Brewfile packages failed; 'brew bundle check --verbose --file=mac/Brewfile' shows which"
fi
echo

# 4. gum, which draws the setup menu's checklist. Pinned release binary, not
# the Homebrew formula -- see ensure_gum in common.sh for why.
# set -e is active, and the menu works without it, so a failure only warns.
ensure_gum || warn "Continuing without gum; the setup menu will use its numbered fallback."
echo

# 5. The terminal font. Homebrew has font-fira-code-nerd-font, but this pulls
# the same GitHub release the Linux and Windows installers use, checksum
# included, so every machine ends up on an identical version.
install_nerd_font FiraCode 'FiraCodeNerdFontMono-*.ttf' 'FiraCode Nerd Font Mono' ||
    warn "Continuing without the font; prompt glyphs will not render."
echo

# 6. Rust, through upstream rustup so macOS, Linux and Windows all manage
# toolchains the same way.
#
# --no-modify-path, because rustup would otherwise append its own PATH line to
# ~/.zshenv, ~/.bashrc and ~/.profile. shared/shell/rust.sh does that instead,
# so the shell config stays in the repo.
step "Installing rustup..."
# An `if` rather than `[ -f ... ] && ...`: under set -e a failing test as the
# last command of an AND-list takes the whole script down with it.
# shellcheck disable=SC1091
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
if command -v rustup >/dev/null 2>&1; then
    ok "rustup already installed ($(rustup --version 2>/dev/null | head -n1))"
    rustup update || warn "rustup update failed; the existing toolchain is unchanged"
else
    if curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
            sh -s -- -y --no-modify-path --default-toolchain stable; then
        # shellcheck disable=SC1091
        if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
        ok "rustup installed ($(rustup --version 2>/dev/null | head -n1))"
    else
        warn "rustup install failed; continuing without Rust (see https://rustup.rs)"
    fi
fi
echo

# 7. mise's tools: node, python, go, uv and ruff, pinned in
# shared/mise/config.toml. mise itself came from the Brewfile. Replaces the
# old nvm, python@3.14 formula and /usr/local/go installs.
mise_install_tools || warn "Re-run 'mise install' in a new shell to finish."
# Go tools that only ship as source (folgit, ...), through gup -- see
# shared/gup/README.md. Needs mise's go, so it comes after the line above.
go_tools_install || true
echo

# 8. Git identity, if it is not set yet
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

# delta came from the Brewfile; now that it exists, make it git's pager.
dot_git_delta_include || true
echo

echo -e "${BOLD}${GREEN}=== Base Tools Installation Complete ===${NC}"
echo
echo -e "${YELLOW}IMPORTANT: If Docker Desktop was just installed, open it from Applications"
echo -e "to complete the setup and grant necessary permissions.${NC}"
echo
echo -e "${BLUE}Open a new shell to pick up mise, starship, zoxide, fzf and atuin.${NC}"
echo -e "${BLUE}Authenticate the GitHub CLI when you are ready: ${BOLD}gh auth login${NC}"
echo -e "${BLUE}Check what mise manages: ${BOLD}mise ls${NC}${BLUE}   Rust: ${BOLD}rustup show${NC}"
