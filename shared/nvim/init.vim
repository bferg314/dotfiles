" Neovim reads the same config as vim: shared/vim/.vimrc, through whichever
" name Link dotfiles gave it on this platform (~/.vimrc, or ~/_vimrc on
" Windows). Neovim-only settings can go below the source line.
"
" vim's runtime dirs are added first so anything installed under ~/.vim
" (or ~/vimfiles) is visible to Neovim as well.
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath

if filereadable(expand('~/.vimrc'))
    source ~/.vimrc
elseif filereadable(expand('~/_vimrc'))
    source ~/_vimrc
endif
