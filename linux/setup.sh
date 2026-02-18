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

show_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║     Dotfiles Setup & Installation      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  1) Create Links"
    echo "  2) Install VimPlug"
    echo "  3) Install zsh"
    echo "  4) Install Base Tools"
    echo "  5) Install Desktop Apps"
    echo "  6) Install Server Tools"
    echo "  7) Update"
    echo "  8) Quit"
    echo
}

while true; do
    show_menu
    read -p $'\033[1m\033[0;34mEnter your choice (1-8):\033[0m ' choice
    echo
    [ -z "$choice" ] && break

    case $choice in
    1)
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

        # Create and link bashrc.d
        mkdir -p ~/.bashrc.d
        ln -s -f "$REPO_ROOT/linux/bashrc.d/"* ~/.bashrc.d/

        # Link other dotfiles
        ln -s -f "$REPO_ROOT/linux/vim/.vimrc" ~/.vimrc
        ln -s -f "$REPO_ROOT/linux/tmux/.tmux.conf" ~/.tmux.conf

        # Configure .bashrc to source bashrc.d
        if ! grep -q "Source all files from bashrc.d directory" ~/.bashrc; then
            echo '
# Source all files from bashrc.d directory
if [ -d ~/.bashrc.d ]; then
    for file in ~/.bashrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.bashrc
            echo "✓ Added bashrc.d sourcing to ~/.bashrc"
        else
            echo "✓ ~/.bashrc already configured"
        fi

        # Configure .zshrc to source bashrc.d (if zsh is installed)
        if [ -f ~/.zshrc ]; then
            if ! grep -q "Source all files from bashrc.d directory" ~/.zshrc; then
                echo '
# Source all files from bashrc.d directory (shared with bash)
if [ -d ~/.bashrc.d ]; then
    for file in ~/.bashrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.zshrc
                echo "✓ Added bashrc.d sourcing to ~/.zshrc"
            else
                echo "✓ ~/.zshrc already configured"
            fi
        fi

        echo "✓ Setup complete! Links created and shell configured."
        echo "  Run '. ~/.bashrc' to apply changes to your current session."
        ;;
    2)
        # install vim-plug
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        echo "✓ VimPlug installed."
        echo "  Open vim and run ':PlugInstall' to install your plugins."
        ;;
    3)
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
            # Detect package manager and install zsh
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm zsh
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y zsh
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y zsh
            else
                echo "Unable to detect package manager. Please install zsh manually."
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
        ;;
    4)
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/base.sh"
        "$SCRIPT_DIR/installs/base.sh"
        ;;
    5)
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/desktop.sh"
        "$SCRIPT_DIR/installs/desktop.sh"
        ;;
    6)
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        # Make the install script executable and run it
        chmod +x "$SCRIPT_DIR/installs/server.sh"
        "$SCRIPT_DIR/installs/server.sh"
        ;;
    7)
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
        git -C "$REPO_ROOT" reset --hard HEAD
        git -C "$REPO_ROOT" clean -xffd
        git -C "$REPO_ROOT" pull
        ;;
    8)
        break
        ;;
    *) echo "Invalid option" ;;
    esac

    echo
    read -p "Press Enter to continue..."
done
