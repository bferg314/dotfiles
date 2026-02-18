call plug#begin('~/.vim/plugged')
"
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-commentary'
Plug 'junegunn/limelight.vim'
Plug 'junegunn/goyo.vim'
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

" Allow for saving sessions
map <F2> :mksession! ~/vim_session <cr> " Quick write session with F2
map <F3> :source ~/vim_session <cr>     " And load session with F3

" Use system clipboard (plus for Linux)
" set clipboard=unnamed
set clipboard=unnamedplus

" 4 tabs, spaces, and line breaks
set tabstop=4
set expandtab
set linebreak

" Allow backspace in insert mode
set backspace=indent,eol,start

" Highlight searches
set hlsearch

" Ignore case of searches
set ignorecase

" clear the search pattern
:command C let @/=""

" VTE Compatible terminals cursor mode
" let &t_SI = "\<Esc>[6 q"
" let &t_SR = "\<Esc>[4 q"
" let &t_EI = "\<Esc>[2 q"

" stupid bell
set visualbell
set t_vb=

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
