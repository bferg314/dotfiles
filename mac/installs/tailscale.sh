#!/usr/bin/env bash
# Tailscale installation script for macOS
# Installs the Tailscale app and prints what is left to do by hand. Does not
# log in -- `tailscale up` is left to you, so this stays non-interactive.

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo -e "${BOLD}${CYAN}=== Tailscale Installation (macOS) ===${NC}"
echo

if ! brew_on_path; then
    die "Homebrew is not installed. Run 'Base tools' first."
fi

step "Updating Homebrew..."
brew update
echo

# The cask, not the formula. `brew install tailscale` is the headless tailscaled
# daemon with no GUI; the menu-bar app this installs is the cask. The cask was
# also renamed -- the token is tailscale-app, and the old `tailscale` cask is
# gone.
step "Installing Tailscale..."
brew_cask tailscale-app Tailscale
echo

echo -e "${BOLD}${GREEN}=== Tailscale Installation Complete ===${NC}"
echo

TS_BIN="$(tailscale_bin || true)"

if [ -n "$TS_BIN" ] && TS_IP="$("$TS_BIN" ip -4 2>/dev/null | head -n1)" && [ -n "$TS_IP" ]; then
    echo -e "${BLUE}This machine is on the tailnet as: ${BOLD}${TS_IP}${NC}"
else
    echo -e "${YELLOW}Two things are left, and neither can be scripted:${NC}"
    echo -e "  ${BOLD}1.${NC} Open Tailscale from Applications and approve its system extension"
    echo -e "     when macOS asks (System Settings → Privacy & Security). It cannot"
    echo -e "     connect until you do."
    echo -e "  ${BOLD}2.${NC} Log in to join your tailnet, from the menu bar icon or with:"
    echo -e "     ${BOLD}tailscale up${NC}"
    echo
    echo -e "${BLUE}The CLI is installed at ${BOLD}/usr/local/bin/tailscale${NC}"
fi
echo
