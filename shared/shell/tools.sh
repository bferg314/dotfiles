# shellcheck shell=bash
# Shell integrations for the toolchain: mise, zoxide, fzf, atuin, starship,
# and aliases for eza / bat / lazygit. Sourced by both bash (Linux) and zsh
# (macOS) from ~/.bashrc.d or ~/.zshrc.d; windows/posh.d/tools.ps1 is the
# PowerShell counterpart.
#
# Every block is guarded with `command -v`, so a machine that has not run
# Base tools yet gets a plain shell rather than an error per missing tool.
# Order matters and is the order below:
#   1. mise first -- on Linux it is what puts starship, fzf, atuin and the
#      rest on PATH, so nothing after it can be found until it has run.
#   2. fzf before atuin -- both bind Ctrl-R, and the later one wins. atuin
#      gets history search; fzf keeps Ctrl-T (files) and Alt-C (cd).
#   3. starship last -- it takes over the prompt, and wraps whatever
#      PROMPT_COMMAND / precmd hooks the others installed.

# Only interactive shells; scripts that source ~/.bashrc get none of this.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

if [ -n "${ZSH_VERSION:-}" ]; then
    _dot_shell=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
    _dot_shell=bash
else
    return 0
fi

# ─── mise ─────────────────────────────────────────────────────────────────────
#
# Puts the versions pinned in ~/.config/mise/config.toml (and in any project's
# mise.toml) on PATH, re-evaluated as you cd between projects. The Linux
# installer puts mise in ~/.local/bin, which not every distro has on PATH yet.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) [ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "$_dot_shell")"
fi

# ─── zoxide ───────────────────────────────────────────────────────────────────
#
# `z foo` jumps to the best-ranked directory matching "foo"; `zi foo` picks
# from a list with fzf. It learns from every cd, so it gets better with use.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init "$_dot_shell")"
fi

# ─── fzf ──────────────────────────────────────────────────────────────────────
#
# Ctrl-T pastes a fuzzy-picked file path, Alt-C cds into a fuzzy-picked
# directory, and `**<Tab>` completes paths and hosts with fzf.
if command -v fzf >/dev/null 2>&1; then
    # fd is faster than find and respects .gitignore. Debian/Ubuntu's fd-find
    # package is symlinked to `fd` by the Linux base install.
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
    if command -v bat >/dev/null 2>&1; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    fi
    if command -v eza >/dev/null 2>&1; then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {}'"
    fi

    # `fzf --bash` / `fzf --zsh` exist from fzf 0.48. An older distro fzf --
    # only possible before mise has installed its own -- just goes without the
    # key bindings rather than printing an error on every shell start.
    if _dot_fzf_init="$(fzf --"$_dot_shell" 2>/dev/null)"; then
        eval "$_dot_fzf_init"
    fi
    unset _dot_fzf_init
fi

# ─── atuin ────────────────────────────────────────────────────────────────────
#
# Replaces Ctrl-R with a full-screen, searchable history that records the
# directory, exit code and duration of every command. The Up arrow is left as
# the prefix search set up in history.sh (--disable-up-arrow).
if command -v atuin >/dev/null 2>&1; then
    if [ "$_dot_shell" = bash ]; then
        # bash has no preexec hook of its own, and atuin needs one to record
        # commands. bash-preexec is vendored in the repo (shared/shell/vendor)
        # rather than downloaded, so it is pinned and reviewed like any other
        # file here. This file is a symlink into the repo; resolve it to find
        # the vendored copy.
        _dot_self="${BASH_SOURCE[0]}"
        _dot_real="$(readlink -f "$_dot_self" 2>/dev/null || readlink "$_dot_self" 2>/dev/null || printf '%s' "$_dot_self")"
        _dot_preexec="$(dirname "$_dot_real")/vendor/bash-preexec.sh"
        if [ -f "$_dot_preexec" ]; then
            # shellcheck source=shared/shell/vendor/bash-preexec.sh
            . "$_dot_preexec"
            eval "$(atuin init bash --disable-up-arrow)"
        fi
        unset _dot_self _dot_real _dot_preexec
    else
        eval "$(atuin init zsh --disable-up-arrow)"
    fi
fi

# ─── Modern CLI replacements ──────────────────────────────────────────────────
#
# `ls` itself is left alone so scripts and muscle memory keep working; the
# short forms are what change.
if command -v eza >/dev/null 2>&1; then
    alias l='eza --group-directories-first --icons=auto'
    alias ll='eza -l --git --group-directories-first --icons=auto'
    alias la='eza -la --git --group-directories-first --icons=auto'
    alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
fi

# bat: `cat` with syntax highlighting, line numbers and git markers. Not
# aliased over cat -- `bat` pages long files, which is not what a pipe wants.
# `batp` is the plain, no-pager form for quick looks.
if command -v bat >/dev/null 2>&1; then
    alias batp='bat --paging=never --style=plain'
fi

if command -v lazygit >/dev/null 2>&1; then
    alias lg='lazygit'
fi

# folgit (installed into ~/go/bin by gup, see shared/gup/): a dashboard of
# every repo under a folder. Its init defines a `folgit` wrapper function, so
# pressing `g` on a repo quits folgit and leaves this shell in that repo.
if command -v folgit >/dev/null 2>&1; then
    eval "$(folgit init "$_dot_shell")"
fi

# ─── Prompt ───────────────────────────────────────────────────────────────────
#
# Reads ~/.config/starship.toml, which Link dotfiles points at
# shared/starship/tokyo.toml. With oh-my-zsh this overrides its theme; set
# ZSH_THEME="" in ~/.zshrc to stop oh-my-zsh drawing one first.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init "$_dot_shell")"
fi

unset _dot_shell
