# shellcheck shell=bash
# Go toolchain, shared by bash and zsh.
#
# mise provides `go` itself (shared/mise/config.toml), so the only PATH entry
# left to add is $HOME/go/bin -- GOPATH's default bin dir, where
# `go install example.com/tool@latest` puts binaries, and where gup installs
# and updates the tools in shared/gup/gup.json. mise is set not to move GOBIN
# into its per-version directory (go.set_gobin = false), so this stays put
# across Go upgrades.
#
# Sorted before tools.sh, so tools.sh can find folgit and friends.
if [ -d "$HOME/go/bin" ]; then
    case ":$PATH:" in
        *":$HOME/go/bin:"*) ;;
        *) export PATH="$HOME/go/bin:$PATH" ;;
    esac
fi
