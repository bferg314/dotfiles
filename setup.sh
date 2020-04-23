#!/bin/bash

PS3='Please enter your choice: '
options=("Create Links" "Install VimPlug" "Install zsh" "Update" "Quit")
select opt in "${options[@]}"; do
    case $opt in
    "Create Links")
        ln -s -f ~/git/dotfiles/linux/vim/.vimrc ~/.vimrc
        ln -s -f ~/git/dotfiles/screen/.screenrc ~/.screenrc
        ln -s -f ~/git/dotfiles/tmux/.tmux.conf ~/.tmux.conf
        ln -s -f ~/git/dotfiles/jrnl/.jrnl_config ~/.jrnl_config
        # cat ./bash/.bashrc >> ~/.bashrc
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
