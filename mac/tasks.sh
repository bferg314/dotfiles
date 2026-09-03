#!/usr/bin/env bash
# Task table, handlers and status probes for the macOS setup menu.
# Sourced by mac/setup.sh after lib/menu.sh; not executable on its own.
#
# SCRIPT_DIR and REPO_ROOT are set by setup.sh before this is sourced.

# ─── Status probes ────────────────────────────────────────────────────────────

_missing_commands() {
    local cmd missing=""
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing="${missing:+$missing, }$cmd"
    done
    printf '%s' "$missing"
}

# Casks put an .app in /Applications rather than a binary on PATH.
_missing_apps() {
    local app missing=""
    for app in "$@"; do
        [ -d "/Applications/$app.app" ] || missing="${missing:+$missing, }$app"
    done
    printf '%s' "$missing"
}

status_links() {
    local target
    if [ ! -d "$HOME/.zshrc.d" ]; then
        printf 'not linked'
        return 1
    fi
    target="$(readlink "$HOME/.zshrc.d/alias-zsh.zshrc" 2>/dev/null)"
    case "$target" in
        "$REPO_ROOT"/*) ;;
        "") printf 'links present but broken'; return 1 ;;
        *) printf 'linked to another checkout'; return 1 ;;
    esac
    if ! grep -q "Source all files from zshrc.d directory" "$HOME/.zshrc" 2>/dev/null; then
        printf 'linked, but ~/.zshrc does not source them'
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

status_shell() {
    case "$SHELL" in
        */zsh) ;;
        *) printf 'default shell is %s' "${SHELL:-unknown}"; return 1 ;;
    esac
    if [ -d "$HOME/.oh-my-zsh" ]; then
        printf 'zsh + oh-my-zsh'
        return 0
    fi
    printf 'zsh (no oh-my-zsh)'
    return 1
}

status_base() {
    local missing
    missing="$(_missing_commands brew git node rustup zellij gum yazi)"
    [ -d "/Applications/Docker.app" ] || missing="${missing:+$missing, }Docker"

    # install_rustup runs with --no-modify-path -- ~/.cargo/bin only reaches
    # PATH through zshrc.d/rust.zshrc, which "Link dotfiles" is what actually
    # links in. `command -v rustup` alone cannot tell "never installed" apart
    # from "installed, but Link dotfiles hasn't run (or this shell predates
    # it)", and reporting the latter as plain "missing" sends you chasing a
    # reinstall instead of the one-line fix.
    case ",$missing," in
        *,rustup,*)
            [ -x "$HOME/.cargo/bin/rustup" ] &&
                missing="$(printf '%s' "$missing" | sed 's/rustup/rustup (on disk, not on PATH - run Link dotfiles)/')"
            ;;
    esac

    if [ -n "$missing" ]; then
        printf 'missing: %s' "$missing"
        return 1
    fi
    printf 'installed'
}

status_desktop() {
    local missing
    missing="$(_missing_apps Firefox "Visual Studio Code" Obsidian Spotify Discord Steam)"
    if [ -n "$missing" ]; then
        printf 'missing: %s' "$missing"
        return 1
    fi
    printf 'installed'
}

status_server() {
    local state
    state="$(systemsetup -getremotelogin 2>/dev/null)"
    case "$state" in
        *On) printf 'Remote Login on'; return 0 ;;
        *Off) printf 'Remote Login off'; return 1 ;;
        *) printf 'needs admin to query'; return 2 ;;
    esac
}

status_tailscale() {
    local bin ip
    bin="$(tailscale_bin)" || { printf 'not installed'; return 1; }
    # `tailscale ip -4` only answers once the daemon is up and logged in, so one
    # call covers the system-extension approval, "not running" and "not logged
    # in" alike -- Doctor is where the full `tailscale status` belongs.
    ip="$("$bin" ip -4 2>/dev/null | head -n1)"
    if [ -n "$ip" ]; then
        printf 'up (%s)' "$ip"
        return 0
    fi
    printf 'installed, not connected'
    return 1
}

status_update() { menu_update_status; }

# ─── Handlers ─────────────────────────────────────────────────────────────────

task_links() {
    mkdir -p "$HOME/.zshrc.d"
    ln -s -f "$REPO_ROOT/mac/zshrc.d/"* "$HOME/.zshrc.d/"

    ln -s -f "$REPO_ROOT/mac/vim/.vimrc" "$HOME/.vimrc"
    mkdir -p "$HOME/.config/zellij"
    ln -s -f "$REPO_ROOT/mac/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"

    _link_rc "$HOME/.zshrc" ""
    [ -f "$HOME/.bashrc" ] && _link_rc "$HOME/.bashrc" " (shared with zsh)"

    ok "Links created and shell configured"
    info "Run '. ~/.zshrc' to apply changes to your current session."
}

# Append the zshrc.d sourcing block to an rc file, once.
_link_rc() {
    local rc="$1" note="$2"
    if grep -q "Source all files from zshrc.d directory" "$rc" 2>/dev/null; then
        ok "$(basename "$rc") already configured"
        return 0
    fi
    cat >> "$rc" <<EOF

# Source all files from zshrc.d directory$note
if [ -d ~/.zshrc.d ]; then
    for file in ~/.zshrc.d/*; do
        [ -f "\$file" ] && source "\$file"
    done
fi
EOF
    ok "Added zshrc.d sourcing to $(basename "$rc")"
}

task_vimplug() {
    local url='https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs "$url" || return 1
    curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs "$url" || return 1
    ok "vim-plug installed"
    info "Open vim and run ':PlugInstall' to install your plugins."
}

# macOS has shipped zsh as the default shell since Catalina, so this is mostly
# about oh-my-zsh and about the case where the login shell is still bash.
task_shell() {
    if ! command -v zsh >/dev/null 2>&1; then
        step "Installing zsh..."
        brew_on_path || { warn "Homebrew not found. Run 'Base tools' first."; return 1; }
        brew_install zsh
    else
        ok "zsh already installed"
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        ok "oh-my-zsh already installed"
    else
        local reply=""
        menu_read reply "$(printf '%b' "${CYAN}  Install oh-my-zsh? (y/N) ${NC}")" || return 0
        case "$reply" in
            y | Y | yes | YES)
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
                ;;
        esac
    fi

    case "$SHELL" in
        */zsh) ok "zsh is already the default shell" ;;
        *)
            local reply=""
            menu_read reply "$(printf '%b' "${CYAN}  Set zsh as the default shell? (y/N) ${NC}")" || return 0
            case "$reply" in
                y | Y | yes | YES)
                    chsh -s "$(command -v zsh)" &&
                        ok "Default shell changed to zsh (takes effect on next login)"
                    ;;
            esac
            ;;
    esac
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
    info "macOS:    $(sw_vers -productVersion 2>/dev/null || uname -r)"
    info "arch:     $(uname -m)"
    info "shell:    ${SHELL:-unknown}"
    info "repo:     $REPO_ROOT"
    info "brew:     $(command -v brew >/dev/null 2>&1 && brew --version 2>/dev/null | head -n1 || echo 'not installed')"
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
    sourced="$(grep -c "Source all files from zshrc.d directory" "$HOME/.zshrc" 2>/dev/null)"
    [ -n "$sourced" ] || sourced=0
    # shellcheck disable=SC2088  # these are messages for a human, not paths
    if [ "$sourced" -gt 1 ]; then
        warn "~/.zshrc sources zshrc.d $sourced times - remove the duplicates"
    else
        ok "~/.zshrc sourcing block: $sourced"
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

menu_platform_line() {
    printf 'macOS %s · %s' "$(sw_vers -productVersion 2>/dev/null || uname -r)" "$(uname -m)"
}

# ─── Table ────────────────────────────────────────────────────────────────────
#
# Same ids, groups and run order as linux/tasks.sh, so the two menus read the
# same. The differences are rows, not forked code: macOS has a `shell` task
# where Linux has none, and no mDNS row (Bonjour is built in).
#
#         id|label|group|order|handler|probe|flags

menu_task "workstation|Workstation preset  |presets  | 1|-           |-             |expand:links+shell+vimplug+base+desktop"
menu_task "serverpre  |Server preset       |presets  | 2|-           |-             |expand:links+base+server"

menu_task "links      |Link dotfiles       |configure|10|task_links  |status_links  |"
menu_task "shell      |Shell (zsh)         |configure|15|task_shell  |status_shell  |net"
menu_task "vimplug    |Editor plugins      |configure|20|task_vimplug|status_vimplug|net"

menu_task "base       |Base tools          |install  |30|task_base   |status_base   |net"
menu_task "desktop    |Desktop apps        |install  |40|task_desktop|status_desktop|net,optin"
menu_task "server     |Server tools (SSH)  |install  |50|task_server |status_server |net,sudo,optin"
menu_task "tailscale  |Tailscale (VPN)     |install  |55|task_tailscale|status_tailscale|net,optin"

menu_task "update     |Update from git     |maintain |70|task_update |status_update |net"
menu_task "doctor     |Doctor (full report)|maintain |80|task_doctor |-             |"
menu_task "repos      |Clone GitHub repos  |maintain |90|task_clone_repos|-         |net"
