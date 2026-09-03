call plug#begin('~/.vim/plugged')
"
" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" File navigation
Plug 'ctrlpvim/ctrlp.vim'
Plug 'preservim/nerdtree'

" Code quality
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-commentary'

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Distraction-free writing
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" Personal wiki
Plug 'vimwiki/vimwiki'
"
" All of your Plugins must be added before the following line
call plug#end()

" NERDTree
let NERDTreeShowHidden=1
map <silent> <C-n> :NERDTreeFocus<CR>

" General
set number
syntax on
filetype plugin indent on
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Allow for saving sessions
map <F2> :mksession! ~/vim_session <cr> " Quick write session with F2
map <F3> :source ~/vim_session <cr>     " And load session with F3

" Paste toggle
set pastetoggle=<F4>

set clipboard=unnamed

function! s:goyo_enter()
  set noshowmode
  set noshowcmd
  set scrolloff=999
  Limelight
  set spell
  " ...
endfunction

function! s:goyo_leave()
  set showmode
  set showcmd
  set scrolloff=5
  Limelight!
  " ...
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()

