# shellcheck shell=bash
# List every alias, one per line: name => command. Works in bash and zsh --
# bash prints `alias name='cmd'`, zsh prints `name='cmd'`, so the optional
# `alias ` prefix is stripped either way.
list_aliases() {
    echo "Custom Aliases:"
    echo "---------------"
    local line name cmd
    alias | sed 's/^alias //' | sort | while IFS= read -r line; do
        name="${line%%=*}"
        cmd="${line#*=}"
        cmd="${cmd#\'}"
        cmd="${cmd%\'}"
        printf '%-15s => %s\n' "$name" "$cmd"
    done
    echo
    echo "For more detail on one alias: type <name>"
}

alias lsalias='list_aliases'
