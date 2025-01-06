# History configuration
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE="ls:ll:cd:pwd:exit:clear"

# Append to history instead of overwriting
shopt -s histappend

# forget most recent entry
function forget() {
   history -d $(expr $(history | tail -n 1 | grep -oP '^ \d+') - 1);
}

# Search history with up/down arrows
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Quick history search function
function hg() {
    history | grep "$@"
}

# Clear history
function ch() {
    history -c
    history -w
}