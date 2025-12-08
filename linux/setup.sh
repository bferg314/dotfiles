#!/usr/bin/env bash
# Dotfiles setup script - works with both bash and zsh

PS3='Please enter your choice: '
options=("Create Links" "Install VimPlug" "Install zsh" "Update" "Quit")
select opt in "${options[@]}"; do
    case $opt in
    "Create Links")
        # Get the directory where this script is located
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

        # Create and link bashrc.d
        mkdir -p ~/.bashrc.d
        ln -s -f "$REPO_ROOT/linux/bashrc.d/"* ~/.bashrc.d/

        # Link other dotfiles
        ln -s -f "$REPO_ROOT/linux/vim/.vimrc" ~/.vimrc
        ln -s -f "$REPO_ROOT/linux/screen/.screenrc" ~/.screenrc
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
            # Detect package manager and install zsh
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm zsh
            elif command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y zsh
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y zsh
            else
                echo "Unable to detect package manager. Please install zsh manually."
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
