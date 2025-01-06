call plug#begin('~/.vim/plugged')
"
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/syntastic'
Plug 'vimwiki/vimwiki'
Plug 'tpope/vim-commentary'
"
" All of your Plugins must be added before the following line
call plug#end()

" NERDTree
let NERDTreeShowHidden=1
map <silent> <C-n> :NERDTreeFocus<CR>

" General
set number
syntax on
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

set clipboard=unnamed
