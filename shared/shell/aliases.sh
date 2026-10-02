# shellcheck shell=bash
# Aliases shared by bash and zsh. Platform-specific ones -- GNU vs BSD flags,
# which rc file to reload -- live in linux/bashrc.d/alias-bash.bashrc and
# mac/zshrc.d/alias-zsh.zshrc. tools.sh replaces l/ll/la with eza versions
# when eza is installed.

# Up directory navigation: u1/u = ../  u2/uu = ../../  ... up to 5
_dot_up=""
for _dot_i in 1 2 3 4 5; do
    _dot_up="${_dot_up}../"
    # shellcheck disable=SC2139  # expanded now on purpose
    alias "u$_dot_i=cd $_dot_up"
done
alias u='cd ..' uu='cd ../..' uuu='cd ../../..' uuuu='cd ../../../..' uuuuu='cd ../../../../..'
unset _dot_up _dot_i

# Listings
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Safer defaults
alias mkdir='mkdir -p'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias df='df -h'
alias du='du -h'
alias grep='grep --color=auto'

# Quick edits
alias e_vim='vim ~/.vimrc'
alias e_zellij='vim ~/.config/zellij/config.kdl'
alias e_mise='vim ~/.config/mise/config.toml'
alias e_cron='crontab -e'

# General shortcuts
alias c='clear'
alias x='exit'
alias h='history'
alias j='jobs -l'

# Directory stack
alias -- -='cd -'
alias d='dirs -v'

# System
path() { printf '%s\n' "$PATH" | tr ':' '\n'; }
alias myip='curl -fsS ifconfig.me; echo'
