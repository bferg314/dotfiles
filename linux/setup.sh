#!/bin/bash

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
        if ! grep -q "source ~/.bashrc.d/\*" ~/.bashrc; then
            echo '
# Source all files from bashrc.d directory
if [ -d ~/.bashrc.d ]; then
    for file in ~/.bashrc.d/*; do
        [ -f "$file" ] && source "$file"
    done
fi' >> ~/.bashrc
        fi

        source ~/.bashrc
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
