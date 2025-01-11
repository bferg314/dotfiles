# Enhanced history management

if [ -n "$ZSH_VERSION" ]; then
    HISTFILE=~/.zsh_history
    HISTSIZE=10000
    SAVEHIST=10000

    setopt appendhistory
    setopt sharehistory
    setopt incappendhistory
    setopt extendedhistory
fi
