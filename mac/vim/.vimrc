" Vim configuration

call plug#begin('~/.vim/plugged')

" Status line
Plug 'vim-airline/vim-airline'

" File navigation
Plug 'preservim/nerdtree'

" Distraction-free writing
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

call plug#end()

" General settings
set number
syntax on
filetype plugin indent on
set tabstop=4
set shiftwidth=4
set expandtab
