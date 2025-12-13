# Up directory navigation - u/u1 = ../  uu/u2 = ../../  etc
for i in {1..5}; do
    dots=$(printf "%$i.${i}s" "../" | sed 's/ /\.\.\//g')
    eval "alias u$i='cd $dots'"
    eval "alias $(printf 'u%.0s' $(seq $i))='cd $dots'"
done

# File navigation and management
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias mkdir='mkdir -p'
alias df='df -h'
alias du='du -h'

# Quick edits
alias e_vim='vim ~/.vimrc'
alias e_zsh='vim ~/.zshrc'
alias e_tmux='vim ~/.tmux.conf'
alias e_bash='vim ~/.bashrc'
alias e_cron='crontab -e'

# general shortcuts
alias c='clear'
alias x='exit'
alias h='history'
alias j='jobs -l'
alias rc='source ~/.zshrc && clear'

# Directory navigation (improved)
alias -- -='cd -'      # Go to previous directory
alias d='dirs -v'      # List directory stack

# System shortcuts
alias path='echo -e ${PATH//:/\\n}'   # Pretty print PATH
alias ports='netstat -tulanp'         # Show active ports
alias mem='free -h'                   # Memory use
alias disk='df -h /'                  # Disk usage
alias 'ps?=ps aux | grep'             # Process search
alias myip='curl ifconfig.me'         # External IP

# Make some possibly destructive commands more interactive.
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Make grep more user friendly by highlighting matches
# and exclude grepping through .svn folders.
alias grep='grep --color=auto --exclude-dir=\.svn'

# Fedora-specific aliases
if [ -f /etc/fedora-release ]; then
    # Vim with X support
    alias vim=vimx
fi




