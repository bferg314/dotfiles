# shellcheck shell=bash
# History settings, shared by bash and zsh. When atuin is installed it takes
# over Ctrl-R (see tools.sh), but these still control the shell's own history
# file and the Up/Down prefix search.

HISTSIZE=10000

if [ -n "${BASH_VERSION:-}" ]; then
    HISTFILESIZE=20000
    HISTCONTROL=ignoreboth:erasedups
    HISTIGNORE="ls:ll:cd:pwd:exit:clear"
    # Append to the history file instead of overwriting it
    shopt -s histappend
fi

if [ -n "${ZSH_VERSION:-}" ]; then
    HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
    # shellcheck disable=SC2034  # read by zsh, not by this file
    SAVEHIST=10000
    setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY EXTENDED_HISTORY
    setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS
fi

# Up/Down search history for lines starting with what is already typed
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

if [ -n "${ZSH_VERSION:-}" ]; then
    bindkey '^[[A' history-beginning-search-backward
    bindkey '^[[B' history-beginning-search-forward
fi

# Forget the previous command (bash only -- zsh has no way to delete a single
# history entry). Removes the command before `forget` and then `forget`
# itself. atuin keeps its own copy: remove it there with
# `atuin search --delete '<text>'` (run without --delete first to preview).
if [ -n "${BASH_VERSION:-}" ]; then
    forget() {
        local n
        n="$(history 1 | awk '{print $1}')"
        history -d "$((n - 1))" && history -d "$((n - 1))"
    }
fi

# Search history for a pattern. `history` alone lists everything in bash but
# only the last 16 entries in zsh, where `history 1` means "from entry 1".
hg() {
    if [ -n "${BASH_VERSION:-}" ]; then
        history | grep -i -- "$@"
    else
        history 1 | grep -i -- "$@"
    fi
}

# Clear history, in memory and on disk
ch() {
    if [ -n "${BASH_VERSION:-}" ]; then
        history -c
        history -w
    else
        : > "${HISTFILE:-$HOME/.zsh_history}"
        fc -p
    fi
}
