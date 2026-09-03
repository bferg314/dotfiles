#!/usr/bin/env bash
# Task table, handlers and status probes for the Linux setup menu.
# Sourced by linux/setup.sh after lib/menu.sh; not executable on its own.
#
# SCRIPT_DIR and REPO_ROOT are set by setup.sh before this is sourced.

# ─── Status probes ────────────────────────────────────────────────────────────
#
# Each prints a short detail for the menu's right-hand column and returns
# 0 (done), 1 (not done) or 2 (unknown). They must be cheap: they all run on
# every redraw.

# Names of the given commands that are not on PATH.
_missing_commands() {
    local cmd missing=""
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing="${missing:+$missing, }$cmd"
    done
    printf '%s' "$missing"
}

status_links() {
    local target
    if [ ! -d "$HOME/.bashrc.d" ]; then
        printf 'not linked'
        return 1
    fi
    # A stale ~/.bashrc.d full of links into a repo that has since moved looks
    # identical to a working one until a shell starts, so resolve one of them.
    target="$(readlink -f "$HOME/.bashrc.d/alias-bash.bashrc" 2>/dev/null)"
    case "$target" in
        "$REPO_ROOT"/*) ;;
        "") printf 'links present but broken'; return 1 ;;
        *) printf 'linked to another checkout'; return 1 ;;
    esac
    if ! grep -q "Source all files from bashrc.d directory" "$HOME/.bashrc" 2>/dev/null; then
        printf 'linked, but ~/.bashrc does not source them'
        return 1
    fi
    printf 'linked'
}

status_vimplug() {
    if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
        printf 'installed'
        return 0
    fi
    printf 'not installed'
    return 1
}

status_base() {
    local missing
    missing="$(_missing_commands docker git gh node rustup zellij gum yazi)"
    if [ -n "$missing" ]; then
        printf 'missing: %s' "$missing"
        return 1
    fi
    printf 'installed'
}

status_desktop() {
    local missing
    missing="$(_missing_commands firefox code obsidian spotify discord steam)"
    if [ -n "$missing" ]; then
        printf 'missing: %s' "$missing"
        return 1
    fi
    printf 'installed'
}

status_server() {
    command -v systemctl >/dev/null 2>&1 || { printf 'no systemd'; return 2; }
    if systemctl is-enabled sshd >/dev/null 2>&1 || systemctl is-enabled ssh >/dev/null 2>&1; then
        printf 'sshd enabled'
        return 0
    fi
    printf 'sshd not enabled'
    return 1
}

status_tailscale() {
    command -v tailscale >/dev/null 2>&1 || { printf 'not installed'; return 1; }
    # `tailscale ip -4` only answers once the daemon is up and logged in, so one
    # call covers both "not running" and "not logged in" -- Doctor is where the
    # full `tailscale status` belongs.
    local ip
    ip="$(tailscale ip -4 2>/dev/null | head -n1)"
    if [ -n "$ip" ]; then
        printf 'up (%s)' "$ip"
        return 0
    fi
    printf 'installed, not connected'
    return 1
}

status_mdns() {
    command -v systemctl >/dev/null 2>&1 || { printf 'no systemd'; return 2; }
    if systemctl is-active avahi-daemon >/dev/null 2>&1; then
        printf 'discoverable as %s.local' "${HOSTNAME:-$(uname -n)}"
        return 0
    fi
    printf 'avahi not running'
    return 1
}

status_update() { menu_update_status; }

# ─── Handlers ─────────────────────────────────────────────────────────────────

task_links() {
    mkdir -p "$HOME/.bashrc.d"
    ln -s -f "$REPO_ROOT/linux/bashrc.d/"* "$HOME/.bashrc.d/"

    ln -s -f "$REPO_ROOT/linux/vim/.vimrc" "$HOME/.vimrc"
    mkdir -p "$HOME/.config/zellij"
    ln -s -f "$REPO_ROOT/linux/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"

    _link_rc "$HOME/.bashrc" ""
    [ -f "$HOME/.zshrc" ] && _link_rc "$HOME/.zshrc" " (shared with bash)"

    ok "Links created and shell configured"
    info "Run '. ~/.bashrc' to apply changes to your current session."
}

# Append the bashrc.d sourcing block to an rc file, once.
_link_rc() {
    local rc="$1" note="$2"
    if grep -q "Source all files from bashrc.d directory" "$rc" 2>/dev/null; then
        ok "$(basename "$rc") already configured"
        return 0
    fi
    cat >> "$rc" <<EOF

# Source all files from bashrc.d directory$note
if [ -d ~/.bashrc.d ]; then
    for file in ~/.bashrc.d/*; do
        [ -f "\$file" ] && source "\$file"
    done
fi
EOF
    ok "Added bashrc.d sourcing to $(basename "$rc")"
}

task_vimplug() {
    local url='https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs "$url" || return 1
    curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs "$url" || return 1
    ok "vim-plug installed"
    info "Open vim and run ':PlugInstall' to install your plugins."
}

# The installers use `set -e`, so they run as subprocesses -- sourcing them
# would take the menu down with them on the first failed package.
_run_install() {
    local script="$SCRIPT_DIR/installs/$1.sh"
    [ -f "$script" ] || { warn "Install script not found: $script"; return 1; }
    chmod +x "$script"
    "$script"
}

task_base()    { _run_install base; }
task_desktop() { _run_install desktop; }
task_server()  { _run_install server; }
task_tailscale() { _run_install tailscale; }
task_mdns()    { _run_install avahi; }
task_update()  { menu_update_repo; }

# Lists your GitHub repos, skips anything already checked out under ~/code,
# and lets you pick which of the rest to clone there.
task_clone_repos() {
    command -v gh >/dev/null 2>&1 || { warn "GitHub CLI (gh) not found - run 'Base tools' first"; return 1; }
    command -v gum >/dev/null 2>&1 || { warn "gum not found - run 'Base tools' first"; return 1; }
    gh auth status >/dev/null 2>&1 || { warn "gh is not logged in - run 'gh auth login' first"; return 1; }

    local code_dir="$HOME/code"
    mkdir -p "$code_dir"

    step "Fetching your GitHub repositories..."
    local all_repos
    all_repos="$(gh repo list --limit 1000 --json name --jq '.[].name')" || { warn "Could not list repositories"; return 1; }

    local repo uncloned=()
    for repo in $all_repos; do
        [ -d "$code_dir/$repo" ] || uncloned+=("$repo")
    done

    if [ ${#uncloned[@]} -eq 0 ]; then
        ok "All repositories are already cloned in $code_dir"
        return 0
    fi

    local selected
    selected="$(printf '%s\n' "${uncloned[@]}" |
        gum choose --no-limit --height 15 --header "space toggles - enter clones - esc cancels")"

    if [ -z "$selected" ]; then
        info "Nothing selected."
        return 0
    fi

    local failures=0
    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        step "Cloning $repo..."
        gh repo clone "$repo" "$code_dir/$repo" || failures=$((failures + 1))
    done <<EOF
$selected
EOF

    if [ "$failures" = "0" ]; then
        ok "Cloned into $code_dir"
    else
        warn "$failures repo(s) failed to clone"
        return 1
    fi
}

task_doctor() {
    printf '%b\n' "${BOLD}Environment${NC}"
    info "distro:   ${DISTRO:-unknown} (${PKG_MANAGER:-unknown})"
    info "arch:     $(uname -m)"
    info "kernel:   $(uname -r)"
    info "shell:    ${SHELL:-unknown}"
    info "repo:     $REPO_ROOT"
    info "gum:      $(command -v gum >/dev/null 2>&1 && gum --version 2>/dev/null || echo 'not installed (menu uses the numbered fallback)')"
    printf '\n'

    printf '%b\n' "${BOLD}Git identity${NC}"
    info "name:     $(git config --global user.name 2>/dev/null || echo '(unset)')"
    info "email:    $(git config --global user.email 2>/dev/null || echo '(unset)')"
    printf '\n'

    printf '%b\n' "${BOLD}Tasks${NC}"
    local i=0 probe detail rc
    while [ "$i" -lt "$MENU_ROW_COUNT" ]; do
        probe="$(menu_probe "$i")"
        if [ -n "$probe" ] && [ "$probe" != "-" ]; then
            detail="$("$probe" 2>/dev/null)"
            rc=$?
            case $rc in
                0) ok "$(menu_label "$i"): $detail" ;;
                1) warn "$(menu_label "$i"): $detail" ;;
                *) warn "$(menu_label "$i"): $detail (unknown)" ;;
            esac
        fi
        i=$((i + 1))
    done
    printf '\n'

    printf '%b\n' "${BOLD}Shell config${NC}"
    # grep -c returns 1 for "file exists, no matches" and 2 for "no such file",
    # so the exit status is not usable here -- take the count, or zero.
    local sourced
    sourced="$(grep -c "Source all files from bashrc.d directory" "$HOME/.bashrc" 2>/dev/null)"
    [ -n "$sourced" ] || sourced=0
    # shellcheck disable=SC2088  # these are messages for a human, not paths
    if [ "$sourced" -gt 1 ]; then
        warn "~/.bashrc sources bashrc.d $sourced times - remove the duplicates"
    else
        ok "~/.bashrc sourcing block: $sourced"
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

menu_platform_line() {
    printf '%s · %s' "${DISTRO:-$(uname -s)}" "$(uname -m)"
}

# ─── Table ────────────────────────────────────────────────────────────────────
#
#         id|label|group|order|handler|probe|flags

menu_task "workstation|Workstation preset      |presets  | 1|-           |-             |expand:links+vimplug+base+desktop"
menu_task "serverpre  |Server preset           |presets  | 2|-           |-             |expand:links+base+server+mdns"

menu_task "links      |Link dotfiles           |configure|10|task_links  |status_links  |"
menu_task "vimplug    |Editor plugins          |configure|20|task_vimplug|status_vimplug|net"

menu_task "base       |Base tools              |install  |30|task_base   |status_base   |net,sudo"
menu_task "desktop    |Desktop apps            |install  |40|task_desktop|status_desktop|net,sudo,optin"
menu_task "server     |Server tools (SSH)      |install  |50|task_server |status_server |net,sudo,optin"
menu_task "tailscale  |Tailscale (VPN)         |install  |55|task_tailscale|status_tailscale|net,sudo,optin"
menu_task "mdns       |Network discovery (mDNS)|install  |60|task_mdns   |status_mdns   |net,sudo,optin"

menu_task "update     |Update from git         |maintain |70|task_update |status_update |net"
menu_task "doctor     |Doctor (full report)    |maintain |80|task_doctor |-             |"
menu_task "repos      |Clone GitHub repos      |maintain |90|task_clone_repos|-         |net"
