# History configuration
HISTSIZE=10000
HISTFILESIZE=20000

# Bash-specific settings
if [ -n "$BASH_VERSION" ]; then
    HISTCONTROL=ignoreboth:erasedups
    HISTIGNORE="ls:ll:cd:pwd:exit:clear"
    # Append to history instead of overwriting
    shopt -s histappend
fi

# Zsh-specific settings
if [ -n "$ZSH_VERSION" ]; then
    SAVEHIST=10000
    setopt HIST_IGNORE_ALL_DUPS
    setopt HIST_FIND_NO_DUPS
    setopt APPEND_HISTORY
fi

# forget most recent entry
function forget() {
   history -d $(expr $(history | tail -n 1 | grep -oP '^ \d+') - 1);
}

# Search history with up/down arrows
if [ -n "$BASH_VERSION" ]; then
    bind '"\e[A": history-search-backward'
    bind '"\e[B": history-search-forward'
fi

if [ -n "$ZSH_VERSION" ]; then
    bindkey '^[[A' history-beginning-search-backward
    bindkey '^[[B' history-beginning-search-forward
fi

# Quick history search function
function hg() {
    history | grep "$@"
}

# Clear history
function ch() {
    history -c
    history -w
}