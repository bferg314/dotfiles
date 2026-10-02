# shellcheck shell=bash
# zsh- and macOS-specific aliases. Everything shared with bash on Linux is in
# shared/shell/, which Link dotfiles links into ~/.zshrc.d alongside this.

# BSD ls colour flag (GNU ls on Linux uses --color=auto instead)
alias ls='ls -G'

# Reload and edit this shell's config
alias rc='source ~/.zshrc && clear'
alias e_zsh='vim ~/.zshrc'

# System (macOS tools)
alias ports='lsof -iTCP -sTCP:LISTEN -n -P'   # listening TCP ports
alias disk='df -h /'                          # root volume usage
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

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
