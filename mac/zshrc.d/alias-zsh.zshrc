# Common shell aliases and navigation shortcuts

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias u='cd ..'
alias uu='cd ../..'
alias uuu='cd ../../..'
alias uuuu='cd ../../../..'
alias grep='grep --color=auto'

# Run dotfiles setup from anywhere - the counterpart to dotsetup in
# linux/bashrc.d/alias-bash.bashrc and windows/posh.d/aliases.ps1.
#
# A single readlink rather than `readlink -f`: setup.sh links these files
# directly at the repo, so one hop is enough, and BSD readlink on macOS only
# grew -f in Ventura.
dotsetup() {
    local link="$HOME/.zshrc.d/alias-zsh.zshrc"
    local target
    target="$(readlink "$link" 2>/dev/null)"
    [ -n "$target" ] || target="$link"
    bash "$(cd "$(dirname "$target")/.." && pwd)/setup.sh"
}
