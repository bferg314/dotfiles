# Custom PS1
# export PS1='\[\e[37m\][\[\e[m\]\[\e[34m\]\t\[\e[m\]] \[\e]0;\w\a\]\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\]\n\$ '

# ALways vim
VISUAL=vim
export VISUAL EDITOR=vim
export EDITOR

if [ $TILIX_ID ] || [ $VTE_VERSION ]; then
    source /etc/profile.d/vte.sh
fi

# My Custom Aliases
# quick edits
alias e_vim='vim ~/.vimrc'
alias e_zsh='vim ~/.zshrc'
alias e_tmux='vim ~/.tmux.conf'
alias e_alias='vim ~/.bash_aliases'
alias e_bash='vim ~/.bashrc'
alias e_cron='crontab -e'

# ls
# alias ls='ls --color=auto'
# alias l='ls -la'
# alias l.='ls -d .* --color=auto'

# general shortcuts
alias c='clear'
alias x='exit'
alias h='history'
alias j='jobs -l'
alias rc='source ~/.zshrc && clear'

# Make some possibly destructive commands more interactive.
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Make grep more user friendly by highlighting matches
# and exclude grepping through .svn folders.
alias grep='grep --color=auto --exclude-dir=\.svn'

# speedy cd
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'

# forget most recent entry
function forget() {
   history -d $(expr $(history | tail -n 1 | grep -oP '^ \d+') - 1);
}

PATH=$PATH:~/.local/bin

