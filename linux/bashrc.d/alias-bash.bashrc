# shellcheck shell=bash
# bash- and Linux-specific aliases. Everything shared with zsh on macOS is in
# shared/shell/, which Link dotfiles links into ~/.bashrc.d alongside this.

# GNU coreutils colour flag (BSD ls on macOS uses -G instead)
alias ls='ls --color=auto'

# Reload and edit this shell's config
alias rc='source ~/.bashrc && clear'
alias e_bash='vim ~/.bashrc'

# System (Linux tools)
alias ports='ss -tulanp'      # listening and connected sockets
alias mem='free -h'           # memory use
alias disk='df -h /'          # root filesystem usage

# Run dotfiles setup from anywhere. This file is a symlink into the repo;
# resolve it to find setup.sh next to it.
dotsetup() {
    bash "$(dirname "$(readlink -f ~/.bashrc.d/alias-bash.bashrc)")/../setup.sh"
}
