# Rust toolchain (rustup)
#
# installs/base.sh runs rustup with --no-modify-path so it does not append its
# own block to ~/.bashrc, ~/.profile and ~/.zshenv. This is that block, kept in
# the repo instead. Sourcing ~/.cargo/env rather than exporting PATH directly:
# it is what rustup itself writes, and it skips the entry when it is already
# there.
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
elif [ -d "$HOME/.cargo/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.cargo/bin:"*) ;;
        *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac
fi

# Common cargo commands
# Not `cc` for cargo check - that is the C compiler, and build scripts and
# habits both expect it to stay itself.
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias ck='cargo check'
alias cfmt='cargo fmt'
alias ccl='cargo clippy'
