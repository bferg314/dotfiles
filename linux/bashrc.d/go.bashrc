# Go toolchain
#
# installs/base.sh installs Go to /usr/local/go from the upstream tarball
# (install_go in installs/common.sh) rather than a distro package, so nothing
# puts it on PATH automatically. This does that, plus $HOME/go/bin, GOPATH's
# default location for binaries `go install` puts there.
if [ -d /usr/local/go/bin ]; then
    case ":$PATH:" in
        *":/usr/local/go/bin:"*) ;;
        *) export PATH="/usr/local/go/bin:$PATH" ;;
    esac
fi

if [ -d "$HOME/go/bin" ]; then
    case ":$PATH:" in
        *":$HOME/go/bin:"*) ;;
        *) export PATH="$HOME/go/bin:$PATH" ;;
    esac
fi
