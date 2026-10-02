# shellcheck shell=bash
# Utility functions, shared by bash and zsh.

# Make a directory (and its parents) and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.rar)     unrar x "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.Z)       uncompress "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Create a backup copy next to a file
bak() {
    cp "$1" "$1.bak"
}

# Find files by name, case-insensitively. Uses fd when it is installed, which
# is faster and skips .gitignore'd files.
ff() {
    if command -v fd >/dev/null 2>&1; then
        fd --type f --ignore-case "$1"
    else
        find . -type f -iname "*$1*"
    fi
}

# Grep running processes. A function rather than the old `ps?` alias: zsh
# treats `?` as a glob character, so that alias could not be called there.
psg() {
    # shellcheck disable=SC2009  # pgrep cannot show the full ps columns
    ps aux | grep -i -- "$1" | grep -v grep
}
