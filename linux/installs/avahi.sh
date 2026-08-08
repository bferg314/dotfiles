#!/usr/bin/env bash
# Avahi (mDNS/DNS-SD) installation script
# Installs avahi daemon and tools, starts the service, and opens firewall ports

set -e  # Exit on error

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

echo -e "${BOLD}${CYAN}=== Avahi (mDNS) Installation ===${NC}"
echo

detect_distro

# Update package lists
step "Updating package lists..."
pkg_update
echo

# 1. Install Avahi daemon and tools
step "Installing Avahi..."
case "$PKG_MANAGER" in
    pacman) pkg_install avahi nss-mdns ;;
    dnf)    pkg_install avahi avahi-tools nss-mdns ;;
    apt)    pkg_install avahi-daemon avahi-utils libnss-mdns ;;
esac
ok "Avahi installed"
echo

# 2. Enable and start avahi-daemon
step "Enabling avahi-daemon service..."
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon
ok "avahi-daemon enabled and started"
echo

# 3. Ensure NSS mdns is configured
if [ -f /etc/nsswitch.conf ]; then
    if grep -q 'mdns_minimal' /etc/nsswitch.conf; then
        ok "NSS already configured for mDNS"
    else
        step "Configuring NSS for mDNS resolution..."
        sudo cp /etc/nsswitch.conf "/etc/nsswitch.conf.backup.$(date +%Y%m%d%H%M%S)"
        # Insert mdns_minimal directly after 'files' rather than rewriting the
        # whole line -- that would drop myhostname, resolve, and anything else
        # the distro configured.
        if grep -qE '^hosts:.*\bfiles\b' /etc/nsswitch.conf; then
            sudo sed -i -E '/^hosts:/ s/\bfiles\b/files mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
        else
            sudo sed -i -E '/^hosts:/ s/:[[:space:]]*/:      mdns_minimal [NOTFOUND=return] /' /etc/nsswitch.conf
        fi
        ok "NSS configured for mDNS"
        info "hosts: line is now -> $(grep '^hosts:' /etc/nsswitch.conf)"
    fi
fi
echo

# 4. Open firewall ports for mDNS (UDP 5353)
step "Configuring firewall for mDNS..."
if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
    # firewalld (Fedora, RHEL, Arch with firewalld)
    sudo firewall-cmd --permanent --add-service=mdns
    sudo firewall-cmd --reload
    ok "firewalld: mDNS service added"
elif command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
    # UFW (Ubuntu/Debian)
    sudo ufw allow 5353/udp comment "mDNS (Avahi)"
    ok "ufw: mDNS port 5353/udp allowed"
elif command -v iptables >/dev/null 2>&1; then
    # Raw iptables fallback
    if sudo iptables -L INPUT -n 2>/dev/null | grep -q "5353"; then
        ok "iptables: mDNS port already open"
    else
        sudo iptables -A INPUT -p udp --dport 5353 -j ACCEPT
        ok "iptables: mDNS port 5353/udp allowed"
        warn "iptables rules are not persistent by default."
        warn "Install iptables-persistent (Debian) or iptables-services (RHEL) to persist."
    fi
else
    warn "No active firewall detected, skipping"
fi
echo

echo -e "${BOLD}${GREEN}=== Avahi Installation Complete ===${NC}"
echo
echo -e "${BLUE}This machine is now discoverable as: ${BOLD}${HOSTNAME:-$(uname -n)}.local${NC}"
echo
echo -e "${BLUE}Avahi daemon status:${NC}"
sudo systemctl status avahi-daemon --no-pager | head -n 3
