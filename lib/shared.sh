#!/usr/bin/env bash
# Helpers shared by linux/ and mac/ for everything under shared/: linking the
# configs, the git includes, and the mise toolchain. Used by linux/tasks.sh,
# mac/tasks.sh and the base installers. The PowerShell counterparts are in
# windows/common.ps1 and windows/setup.ps1.
#
# Source this file, do not execute it. Expects REPO_ROOT to be set, and the
# ok/warn/info helpers from the platform's installs/common.sh.
#
# macOS ships bash 3.2 and mac/setup.sh runs under it: no bash 4 features.

# The ~ in this file's messages is for a human to read, not a path to expand.
# shellcheck disable=SC2088

# ─── Primitives ───────────────────────────────────────────────────────────────

# Symlink <target> to <source>, creating the parent directory. An existing
# symlink is replaced; an existing real file is moved aside to
# <target>.bak-<timestamp> first rather than silently overwritten.
dot_link() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { warn "Source missing, skipping: $src"; return 1; }
    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then
            return 0
        fi
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        local backup
        backup="$dst.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        warn "Backed up existing $(basename "$dst") to $(basename "$backup")"
    fi

    ln -s "$src" "$dst"
}

# Remove symlinks in <dir> that point into this repo but no longer resolve --
# what a file that was moved or deleted in the repo leaves behind, e.g. the
# old ~/.bashrc.d/hist.bashrc after it moved to shared/shell/history.sh.
dot_prune_dangling() {
    local dir="$1" link target
    [ -d "$dir" ] || return 0
    for link in "$dir"/* "$dir"/.[!.]*; do
        [ -L "$link" ] || continue
        [ -e "$link" ] && continue
        target="$(readlink "$link")"
        case "$target" in
            "$REPO_ROOT"/*)
                rm -f "$link"
                info "Removed stale link $(basename "$link")"
                ;;
        esac
    done
}

# Add `[include] path = <file>` to ~/.gitconfig, once. Your own ~/.gitconfig
# keeps your identity and anything machine-specific; the include brings in
# the shared settings.
#
# The include goes at the TOP of the file, not the end. git applies config in
# file order and the last value wins, so an include appended at the end (what
# `git config --add include.path` does) would override every setting you had
# already made in ~/.gitconfig. At the top, everything of yours comes after
# it and wins.
dot_git_include() {
    local file="$1" cfg tmp
    command -v git >/dev/null 2>&1 || { warn "git not installed; skipping the $(basename "$file") include"; return 1; }
    dot_git_has_include "$file" && return 0

    cfg="${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}"
    tmp="$(mktemp)"
    {
        printf '[include]\n\tpath = %s\n' "$file"
        [ -f "$cfg" ] && cat "$cfg"
    } > "$tmp"
    # Written through rather than moved over, so a ~/.gitconfig that is itself
    # a symlink stays one.
    cat "$tmp" > "$cfg"
    rm -f "$tmp"
    ok "~/.gitconfig now includes $(basename "$file") (your own settings still win)"
}

dot_git_has_include() {
    git config --global --get-all include.path 2>/dev/null | grep -qxF "$1"
}

# delta's pager settings are only safe once delta exists: git fails outright
# when core.pager is not on PATH. Called by Link dotfiles and again by Base
# tools after it installs delta.
dot_git_delta_include() {
    # On Linux delta comes from mise, and right after `mise install` it is not
    # on this script's PATH yet -- only on an activated shell's -- so ask mise
    # too. git itself finds it later through that activated PATH.
    local mise
    if command -v delta >/dev/null 2>&1 ||
        { mise="$(mise_bin)" && "$mise" which delta >/dev/null 2>&1; }; then
        dot_git_include "$REPO_ROOT/shared/git/delta.gitconfig"
    else
        info "delta not installed yet; its git pager settings are added by Base tools"
    fi
}

# ─── Shared configs ───────────────────────────────────────────────────────────

# Everything that lives in shared/ and goes to the same place on Linux and
# macOS. The shell snippets are linked by the caller, into its own rc dir.
dot_link_shared() {
    local shared="$REPO_ROOT/shared"

    dot_link "$shared/vim/.vimrc" "$HOME/.vimrc"

    # Neovim reads the same vimrc through init.vim. An init.lua of your own
    # takes precedence and Neovim refuses to start with both, so leave it be.
    if [ -e "$HOME/.config/nvim/init.lua" ]; then
        info "~/.config/nvim/init.lua exists; leaving your Neovim config alone"
    else
        dot_link "$shared/nvim/init.vim" "$HOME/.config/nvim/init.vim"
    fi

    dot_link "$shared/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
    dot_link "$shared/starship/tokyo.toml" "$HOME/.config/starship.toml"
    dot_link "$shared/mise/config.toml" "$HOME/.config/mise/config.toml"
    dot_link "$shared/git/ignore" "$HOME/.config/git/ignore"

    dot_git_include "$shared/git/gitconfig"
    dot_git_delta_include

    ok "Shared configs linked (vim, nvim, zellij, starship, mise, git)"
}

# Link shared/shell/*.sh plus the platform's own snippets into <rc dir>.
dot_link_shell() {
    local rcdir="$1" platform_dir="$2" f
    mkdir -p "$rcdir"
    dot_prune_dangling "$rcdir"
    for f in "$REPO_ROOT"/shared/shell/*.sh "$platform_dir"/*; do
        [ -f "$f" ] || continue
        dot_link "$f" "$rcdir/$(basename "$f")"
    done
    ok "Shell snippets linked into $rcdir"
}

# ─── Status ───────────────────────────────────────────────────────────────────

# Names of shared configs that are not linked to this checkout. Empty when
# everything is in place. Cheap enough for the menu's status column.
dot_shared_missing() {
    local missing="" pair src dst
    for pair in \
        "vim/.vimrc:$HOME/.vimrc" \
        "zellij/config.kdl:$HOME/.config/zellij/config.kdl" \
        "starship/tokyo.toml:$HOME/.config/starship.toml" \
        "mise/config.toml:$HOME/.config/mise/config.toml"; do
        src="$REPO_ROOT/shared/${pair%%:*}"
        dst="${pair#*:}"
        [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] || missing="${missing:+$missing, }$(basename "$dst")"
    done
    dot_git_has_include "$REPO_ROOT/shared/git/gitconfig" || missing="${missing:+$missing, }gitconfig include"
    printf '%s' "$missing"
}

# ─── mise ─────────────────────────────────────────────────────────────────────

# Path to the mise binary, or return 1. Looks beyond PATH because the Linux
# installer puts it in ~/.local/bin, which a shell started before Base tools
# ran may not have on PATH yet; Homebrew's prefixes cover macOS.
mise_bin() {
    local candidate
    if candidate="$(command -v mise 2>/dev/null)"; then
        printf '%s' "$candidate"
        return 0
    fi
    for candidate in "$HOME/.local/bin/mise" /opt/homebrew/bin/mise /usr/local/bin/mise; do
        if [ -x "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# Comma-separated names of tools in the mise config that are not installed
# yet; empty when everything is. Returns 1 when mise itself is missing.
mise_tools_missing() {
    local mise
    mise="$(mise_bin)" || return 1
    # --missing lists only uninstalled versions; the first column is the tool.
    "$mise" ls --missing --no-header 2>/dev/null | awk '{print $1}' | paste -sd, - | sed 's/,/, /g'
}

# Install everything in ~/.config/mise/config.toml. Called by the base
# installers after mise itself is in place; Link dotfiles has already linked
# the config by then, since links run before installs.
mise_install_tools() {
    local mise
    mise="$(mise_bin)" || { warn "mise not found; skipping the runtime installs"; return 1; }

    if [ ! -e "$HOME/.config/mise/config.toml" ]; then
        warn "~/.config/mise/config.toml is not linked yet - run Link dotfiles, then Base tools again"
        return 1
    fi

    # The config was written by this repo, so it is trusted -- without this
    # mise asks interactively the first time it sees the file.
    "$mise" trust --quiet "$HOME/.config/mise/config.toml" >/dev/null 2>&1 || true

    step "Installing mise tools (node, python, go, uv, ruff...)"
    "$mise" install --yes || { warn "Some mise tools failed to install; re-run 'mise install' to retry"; return 1; }
    "$mise" upgrade --yes >/dev/null 2>&1 || true
    ok "mise tools installed"
    "$mise" ls --current 2>/dev/null | sed 's/^/    /'

    # Seed atuin's database from the existing shell history, once. Best-effort:
    # a machine with no history yet has nothing to import, and that must not
    # make the whole install report failure.
    local atuin
    if atuin="$("$mise" which atuin 2>/dev/null)" || atuin="$(command -v atuin 2>/dev/null)"; then
        if [ ! -e "$HOME/.local/share/atuin/history.db" ]; then
            if "$atuin" import auto >/dev/null 2>&1; then
                ok "Imported shell history into atuin"
            fi
        fi
    fi
    return 0
}

# ─── Go tools (gup) ───────────────────────────────────────────────────────────

GUP_MANIFEST_REL="shared/gup/gup.json"

# Where `go install` puts binaries. mise is configured not to set GOBIN
# (go.set_gobin = false in shared/mise/config.toml), so this is Go's own
# default unless you have set GOBIN or GOPATH yourself.
go_bin_dir() {
    printf '%s' "${GOBIN:-${GOPATH:-$HOME/go}/bin}"
}

# Names of the binaries listed in shared/gup/gup.json, one per line.
go_tool_names() {
    grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$REPO_ROOT/$GUP_MANIFEST_REL" 2>/dev/null |
        sed 's/.*"\([^"]*\)"$/\1/'
}

# Comma-separated names from gup.json that are not in the Go bin dir yet.
go_tools_missing() {
    local name missing="" dir
    dir="$(go_bin_dir)"
    for name in $(go_tool_names); do
        [ -x "$dir/$name" ] || missing="${missing:+$missing, }$name"
    done
    printf '%s' "$missing"
}

# Install (or update to latest) every tool in shared/gup/gup.json. Runs
# through `mise exec` so mise's go and gup are on PATH even though this
# script's shell never ran `mise activate`.
go_tools_install() {
    local mise
    mise="$(mise_bin)" || { warn "mise not found; skipping the Go tools"; return 1; }
    step "Installing Go tools from $GUP_MANIFEST_REL (folgit, ...)"
    if "$mise" exec -- gup import --file "$REPO_ROOT/$GUP_MANIFEST_REL"; then
        ok "Go tools installed to $(go_bin_dir)"
    else
        warn "Some Go tools failed to install; re-run 'gup import --file $GUP_MANIFEST_REL' in a new shell"
        return 1
    fi
}

# ─── Doctor ───────────────────────────────────────────────────────────────────

# Leftovers from the pre-mise toolchain that now shadow or duplicate it. Each
# line printed is one finding with the command that fixes it; nothing is
# removed automatically.
dot_legacy_report() {
    local found=0 rc
    if [ -d "$HOME/.nvm" ]; then
        warn "nvm is still installed (~/.nvm); mise manages node now."
        info "  remove: rm -rf ~/.nvm, then delete the NVM_DIR lines nvm added to your rc files"
        found=1
    fi
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ] && grep -q 'NVM_DIR' "$rc" 2>/dev/null; then
            warn "$(basename "$rc") still loads nvm, which slows every shell start"
            found=1
        fi
    done
    if [ -d /usr/local/go ]; then
        warn "An upstream Go tarball is still in /usr/local/go; mise manages go now."
        info "  remove: sudo rm -rf /usr/local/go"
        found=1
    fi
    [ "$found" = 0 ] && ok "No leftovers from the old toolchain (nvm, /usr/local/go)"
    return 0
}

# One line per toolchain component: what is active and where it came from.
dot_toolchain_report() {
    local mise
    if mise="$(mise_bin)"; then
        info "mise:     $("$mise" --version 2>/dev/null | awk '{print $1}') ($mise)"
        "$mise" ls --current 2>/dev/null | awk '{ printf "  → %-9s %s\n", $1":", $2 }'
    else
        warn "mise:     not installed - run Base tools"
    fi
    local go_missing
    go_missing="$(go_tools_missing)"
    if [ -n "$go_missing" ]; then
        warn "go tools: missing $go_missing - run Base tools"
    else
        ok "go tools: $(go_tool_names | paste -sd, - | sed 's/,/, /g') in $(go_bin_dir) (gup update keeps them current)"
    fi
    if command -v git >/dev/null 2>&1; then
        if dot_git_has_include "$REPO_ROOT/shared/git/gitconfig"; then
            ok "git:      shared/git/gitconfig included"
        else
            warn "git:      shared/git/gitconfig not included - run Link dotfiles"
        fi
        if dot_git_has_include "$REPO_ROOT/shared/git/delta.gitconfig"; then
            ok "git:      delta is the pager"
        fi
    fi
}
