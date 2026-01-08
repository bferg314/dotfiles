#!/usr/bin/env bash
# Dotfiles setup script - works with both bash and zsh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Display header
clear
echo -e "${BOLD}${CYAN}"
echo "╔════════════════════════════════════════╗"
echo "║     Dotfiles Setup & Installation      ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

COLUMNS=1
PS3=$'\n\033[1m\033[0;34mEnter your choice (1-8):\033[0m '
options=("Create Links" "Install VimPlug" "Install zsh" "Install Base Tools" "Install Desktop Apps" "Install Server Tools" "Update" "Quit")
select opt in "${options[@]}"; do
    case $opt in
    "Create Links")
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

        # Create and link zshrc.d
        mkdir -p ~/.zshrc.d
        ln -s -f "$REPO_ROOT/mac/zshrc.d/"* ~/.zshrc.d/

        # Link other dotfiles
        ln -s -f "$REPO_ROOT/mac/vim/.vimrc" ~/.vimrc
        ln -s -f "$REPO_ROOT/mac/tmux/.tmux.conf" ~/.tmux.conf

        # Configure .zshrc to source zshrc.d
        if ! grep -q "Source all files from zshrc.d directory" ~/.zshrc; then
            echo '
# Source all files from zshrc.d directory
if [ -d ~/.zshrc.d ]; then
    for file in ~/.zshrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.zshrc
            echo "✓ Added zshrc.d sourcing to ~/.zshrc"
        else
            echo "✓ ~/.zshrc already configured"
        fi

        # Configure .bashrc to source zshrc.d (if bash is used)
        if [ -f ~/.bashrc ]; then
            if ! grep -q "Source all files from zshrc.d directory" ~/.bashrc; then
                echo '
# Source all files from zshrc.d directory (shared with zsh)
if [ -d ~/.zshrc.d ]; then
    for file in ~/.zshrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.bashrc
                echo "✓ Added zshrc.d sourcing to ~/.bashrc"
            else
                echo "✓ ~/.bashrc already configured"
            fi
        fi

        # Source the appropriate rc file based on current shell
        if [ -n "$ZSH_VERSION" ]; then
            source ~/.zshrc
        elif [ -n "$BASH_VERSION" ]; then
            source ~/.bashrc
        fi

        echo "✓ Setup complete! Links created and shell configured."
        break
        ;;
    "Install VimPlug")
        # install vim-plug
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        break
        ;;
    "Install zsh")
        # Check if zsh is already installed
        if command -v zsh >/dev/null 2>&1; then
            echo "✓ zsh is already installed"
            read -p "Install oh-my-zsh? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            fi
        else
            echo "Installing zsh..."
            # macOS usually comes with zsh, but if not, install via Homebrew
            if command -v brew >/dev/null 2>&1; then
                brew install zsh
            else
                echo "Error: Homebrew not found. Please install Homebrew first or run 'Install Base Tools'."
                break
            fi

            # Offer to install oh-my-zsh
            read -p "Install oh-my-zsh? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
            fi

            # Offer to change default shell
            read -p "Set zsh as default shell? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                chsh -s $(which zsh)
                echo "✓ Default shell changed to zsh (will take effect on next login)"
            fi
        fi
        break
        ;;
    "Install Base Tools")
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/base.sh"
        "$SCRIPT_DIR/installs/base.sh"
        break
        ;;
    "Install Desktop Apps")
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/desktop.sh"
        "$SCRIPT_DIR/installs/desktop.sh"
        break
        ;;
    "Install Server Tools")
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/server.sh"
        "$SCRIPT_DIR/installs/server.sh"
        break
        ;;
    "Update")
        git reset --hard HEAD
        git clean -xffd
        git pull
        break
        ;;
    "Quit")
        break
        ;;
    *) echo invalid option ;;
    esac
done
