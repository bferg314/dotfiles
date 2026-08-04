#!/usr/bin/env bash
# Server installation script for Linux servers
# Installs server-specific tools and utilities

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo -e "${BOLD}${CYAN}=== Server Tools Installation ===${NC}"
echo

detect_distro

# Debian/Ubuntu call the unit 'ssh', everyone else 'sshd'
SSH_SERVICE="sshd"
[ "$PKG_MANAGER" = "apt" ] && SSH_SERVICE="ssh"

# Update package lists
step "Updating package lists..."
pkg_update
echo

# 1. Install and configure SSH Server
step "Installing SSH Server..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install openssh
else
    pkg_install openssh-server
fi
sudo systemctl enable "$SSH_SERVICE"
sudo systemctl start "$SSH_SERVICE"
ok "SSH Server installed and enabled"
echo

# Configure SSH for key-only authentication (optional)
read -r -p "$(echo -e "${CYAN}Do you want to configure SSH for key-only authentication? (recommended for servers) (y/n) ${NC}")" -n 1 reply
echo
if [[ $reply =~ ^[Yy]$ ]]; then
    # Refuse to lock the machine out: without an authorized key, disabling
    # password auth means nobody can log in over SSH at all.
    if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
        warn "No keys found in ~/.ssh/authorized_keys."
        warn "Disabling password authentication now would lock you out of SSH."
        read -r -p "$(echo -e "${CYAN}Continue anyway? (y/n) ${NC}")" -n 1 force_reply
        echo
        [[ $force_reply =~ ^[Yy]$ ]] || die "Aborted SSH hardening. Add your public key first, then re-run."
    fi

    HARDENING_CONF="/etc/ssh/sshd_config.d/99-dotfiles-hardening.conf"
    SSHD_BACKUP=""

    # Modern sshd_config pulls in sshd_config.d/*.conf, and distro-shipped
    # drop-ins (e.g. Ubuntu's 50-cloud-init.conf) override the main file.
    # Editing only the main file leaves password auth silently enabled, so
    # write a high-numbered drop-in when Include is present.
    if grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
        sudo install -d -m 755 /etc/ssh/sshd_config.d
        sudo tee "$HARDENING_CONF" > /dev/null <<'EOF'
# Managed by dotfiles/linux/installs/server.sh
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
EOF
        sudo chmod 644 "$HARDENING_CONF"
        info "Wrote ${HARDENING_CONF}"
    else
        SSHD_BACKUP="/etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)"
        sudo cp /etc/ssh/sshd_config "$SSHD_BACKUP"
        # Match the directive whether it is commented, set to yes, or set to no
        sudo sed -i -E 's/^[#[:space:]]*PasswordAuthentication[[:space:]]+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i -E 's/^[#[:space:]]*PubkeyAuthentication[[:space:]]+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        grep -qE '^PasswordAuthentication no' /etc/ssh/sshd_config ||
            echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        grep -qE '^PubkeyAuthentication yes' /etc/ssh/sshd_config ||
            echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        info "Updated /etc/ssh/sshd_config (backup: ${SSHD_BACKUP})"
    fi

    # Validate before restarting, so a bad config cannot take sshd down
    if sudo sshd -t; then
        sudo systemctl restart "$SSH_SERVICE"
        ok "SSH configured for key-only authentication"
        echo -e "${YELLOW}  NOTE: Keep this session open and verify you can log in from"
        echo -e "        another terminal before disconnecting!${NC}"
    else
        if [ -n "$SSHD_BACKUP" ]; then
            sudo cp "$SSHD_BACKUP" /etc/ssh/sshd_config
        else
            sudo rm -f "$HARDENING_CONF"
        fi
        die "sshd config test failed; changes reverted and sshd left running"
    fi
fi
echo

# Optional: Install additional server utilities
read -r -p "$(echo -e "${CYAN}Install additional server monitoring tools? (htop, ncdu, net-tools) (y/n) ${NC}")" -n 1 reply
echo
if [[ $reply =~ ^[Yy]$ ]]; then
    step "Installing monitoring tools..."
    pkg_install htop ncdu net-tools
    ok "Monitoring tools installed"
fi
echo

echo -e "${BOLD}${GREEN}=== Server Tools Installation Complete ===${NC}"
echo
echo -e "${BLUE}SSH Server Status:${NC}"
sudo systemctl status "$SSH_SERVICE" --no-pager | head -n 3
