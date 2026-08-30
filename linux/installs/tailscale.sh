#!/usr/bin/env bash
# Tailscale installation script
# Installs the Tailscale client and enables the daemon. Does not log in --
# `tailscale up` is left to you, so this stays non-interactive.

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo -e "${BOLD}${CYAN}=== Tailscale Installation ===${NC}"
echo

detect_distro

# 1. Install the client
#
# Upstream's installer rather than per-distro repo setup, unlike the Docker and
# GitHub CLI blocks in base.sh. Tailscale's repository URLs embed the Fedora
# release and the apt codename --
#     stable/fedora/39/tailscale.repo
#     stable/ubuntu/noble.noarmor.gpg
# -- so hardcoding that mapping here means a 404 on any distro release they
# have not published for yet. Their script resolves it instead, and covers
# Arch, Fedora, RHEL, Debian and Ubuntu from one code path. The same reasoning
# as install_rustup in common.sh, which pipes sh.rustup.rs.
step "Installing Tailscale..."
if command -v tailscale >/dev/null 2>&1; then
    ok "Tailscale already installed ($(tailscale version 2>/dev/null | head -n1))"
else
    curl -fsSL https://tailscale.com/install.sh | sh
    command -v tailscale >/dev/null 2>&1 || die "Tailscale is not on PATH after install"
    ok "Tailscale installed ($(tailscale version 2>/dev/null | head -n1))"
fi
echo

# 2. Enable and start tailscaled
#
# install.sh normally does this itself, so check before acting rather than
# reporting work that was already done.
step "Enabling tailscaled service..."
if ! command -v systemctl >/dev/null 2>&1; then
    warn "No systemd on this machine; start tailscaled however this system manages services."
else
    # Best-effort, not fatal. `set -e` is active and the client is already
    # installed by this point, so a machine whose unit is missing or masked --
    # a container, or a client installed some other way -- should get a clear
    # line about it rather than a bare systemd error and an aborted script.
    if systemctl is-enabled tailscaled >/dev/null 2>&1; then
        ok "tailscaled already enabled"
    elif sudo systemctl enable tailscaled 2>/dev/null; then
        ok "tailscaled enabled"
    else
        warn "Could not enable tailscaled; is the tailscaled.service unit installed?"
    fi

    if systemctl is-active tailscaled >/dev/null 2>&1; then
        ok "tailscaled already running"
    elif sudo systemctl start tailscaled 2>/dev/null; then
        ok "tailscaled started"
    else
        warn "Could not start tailscaled; check 'systemctl status tailscaled'"
    fi
fi
echo

echo -e "${BOLD}${GREEN}=== Tailscale Installation Complete ===${NC}"
echo

# 3. Report where this leaves the machine
#
# `tailscale ip -4` only answers once the daemon is up and logged in, so it
# doubles as the check for whether anything else is needed.
if TS_IP="$(tailscale ip -4 2>/dev/null | head -n1)" && [ -n "$TS_IP" ]; then
    echo -e "${BLUE}This machine is on the tailnet as: ${BOLD}${TS_IP}${NC}"
    echo
    tailscale status 2>/dev/null | head -n 5
else
    echo -e "${YELLOW}Not connected yet. Log in to join your tailnet:${NC}"
    echo -e "  ${BOLD}sudo tailscale up${NC}"
    echo
    echo -e "${BLUE}That prints a URL to open in a browser. Useful flags:${NC}"
    echo -e "  ${BOLD}--ssh${NC}                 allow SSH from other devices on your tailnet"
    echo -e "  ${BOLD}--advertise-exit-node${NC} offer this machine as an exit node"
fi
echo
