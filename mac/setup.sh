#!/bin/bash

PS3='Please enter your choice: '
options=("Create Links" "Install VimPlug" "Install zsh" "Update" "Quit")
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
        ln -s -f "$REPO_ROOT/mac/screen/.screenrc" ~/.screenrc
        ln -s -f "$REPO_ROOT/mac/tmux/.tmux.conf" ~/.tmux.conf

        # Configure .zshrc to source zshrc.d
        if ! grep -q "source ~/.zshrc.d/\*" ~/.zshrc; then
            echo '
# Source all files from zshrc.d directory
if [ -d ~/.zshrc.d ]; then
    for file in ~/.zshrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.zshrc
        fi

        # Source .zshrc if the current shell is zsh
        if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
            source ~/.zshrc
        fi
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
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
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
