" One vimrc for every platform, and for Neovim too (shared/nvim/init.vim
" sources this file). Platform differences are handled with has() checks
" below rather than with a copy per OS, so a change made here reaches every
" machine. See docs/vim-plugins.md for what each plugin does.

" Windows vim otherwise reads this file as latin1 and mangles the sign glyphs
" further down.
set encoding=utf-8
scriptencoding utf-8

call plug#begin('~/.vim/plugged')

" Status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" File navigation
" fzf.vim drives the fzf binary the base install already puts on PATH. The
" first Plug line is fzf's own vim glue (fzf#run); it does not download a
" second fzf.
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'preservim/nerdtree'

" Code quality
" ALE lints asynchronously with whatever linters are installed (ruff and
" shellcheck below), and replaces syntastic, which is archived upstream.
Plug 'dense-analysis/ale'
Plug 'tpope/vim-commentary'

" Git integration
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" Distraction-free writing
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" Personal wiki
Plug 'vimwiki/vimwiki'

" All plugins must be added before the following line
call plug#end()


" ─── General ─────────────────────────────────────────────────────────────────

set number
syntax on
filetype plugin indent on

" 4-space indents, spaces not tabs, wrap at word boundaries
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set linebreak

" Allow backspace over everything in insert mode
set backspace=indent,eol,start

" Searching: highlight matches, ignore case unless the pattern has capitals
set hlsearch
set incsearch
set ignorecase
set smartcase

" :C clears the search highlight
command! C let @/=""

" No bell
set visualbell
if !has('nvim')
    set t_vb=
endif

" System clipboard. Windows and macOS have a single clipboard (the * register);
" X11/Wayland Linux has two, and + is the one Ctrl-C/Ctrl-V use.
if has('win32') || has('mac') || has('macunix')
    set clipboard=unnamed
else
    set clipboard=unnamedplus
endif

" Window navigation with Ctrl + h/j/k/l
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Sessions: F2 saves, F3 restores. No trailing comments on these lines -- vim
" has no comments after :map, so they would become part of the mapping.
nnoremap <F2> :mksession! ~/vim_session<CR>
nnoremap <F3> :source ~/vim_session<CR>

" F4 toggles paste mode. Neovim removed the option (bracketed paste makes it
" unnecessary), so it is only set in vim.
if !has('nvim')
    set pastetoggle=<F4>
endif


" ─── NERDTree ────────────────────────────────────────────────────────────────

let NERDTreeShowHidden=1
nnoremap <silent> <C-n> :NERDTreeFocus<CR>


" ─── fzf.vim ─────────────────────────────────────────────────────────────────
"
" Ctrl-P keeps the muscle memory from ctrlp.vim. The leader is vim's default, \.

nnoremap <silent> <C-p>     :Files<CR>
nnoremap <silent> <Leader>b :Buffers<CR>
nnoremap <silent> <Leader>r :Rg<CR>
nnoremap <silent> <Leader>h :History<CR>
nnoremap <silent> <Leader>g :GFiles?<CR>


" ─── ALE ─────────────────────────────────────────────────────────────────────
"
" Linters run as you type and on save; fixers only when you ask (\f), so a
" file never changes under you without a keypress.

let g:ale_linters = {
\   'python': ['ruff'],
\   'sh': ['shellcheck'],
\}
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'python': ['ruff', 'ruff_format'],
\}
let g:ale_fix_on_save = 0
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '!'
let g:airline#extensions#ale#enabled = 1

nmap <silent> [g <Plug>(ale_previous_wrap)
nmap <silent> ]g <Plug>(ale_next_wrap)
nmap <silent> <Leader>f <Plug>(ale_fix)
nmap <silent> <Leader>d <Plug>(ale_detail)


" ─── Goyo + Limelight ────────────────────────────────────────────────────────

function! s:goyo_enter()
    set noshowmode
    set noshowcmd
    set scrolloff=999
    Limelight
    set spell
endfunction

function! s:goyo_leave()
    set showmode
    set showcmd
    set scrolloff=5
    Limelight!
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()
