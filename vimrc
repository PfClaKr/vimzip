" vimzip
set nocompatible
let &packpath = $VIMZIP . ',' . $VIMRUNTIME
let &runtimepath = $VIMZIP . ',' . $VIMRUNTIME . ',' . $VIMRUNTIME . '/after'
filetype plugin indent on
syntax on

set encoding=utf-8 fileencodings=ucs-bom,utf-8,cp949,latin1
set number hidden mouse=a laststatus=2 noshowmode signcolumn=yes
set incsearch hlsearch ignorecase smartcase
set backspace=indent,eol,start wildmenu ttimeoutlen=50 updatetime=300
set undofile undodir=~/.cache/vimzip/undo
silent! call mkdir(expand('~/.cache/vimzip/undo'), 'p')

let mapleader = ' '

" ALE: lint on open/save
let g:ale_linters = {'c': ['gcc', 'clang'], 'cpp': ['gcc', 'clang'], 'sh': ['shellcheck']}
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
nmap ]e <Plug>(ale_next_wrap)
nmap [e <Plug>(ale_previous_wrap)

" gutentags: keep tag files out of projects
let g:gutentags_cache_dir = expand('~/.cache/vimzip/tags')

" lightline
let g:lightline = {
  \ 'active': {
  \   'left': [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
  \   'right': [['ale', 'lineinfo'], ['percent'], ['fileformat', 'fileencoding', 'filetype']]},
  \ 'component_function': {'gitbranch': 'FugitiveHead', 'ale': 'VimzipAle'}}
function! VimzipAle() abort
  if !exists('*ale#statusline#Count') | return '' | endif
  let c = ale#statusline#Count(bufnr(''))
  let e = c.error + c.style_error
  return c.total ? printf('E:%d W:%d', e, c.total - e) : ''
endfunction
autocmd User ALELintPost call lightline#update()

" keys
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>t :Tags<CR>
nnoremap <leader>f :Rg<CR>
nnoremap <F2> :NERDTreeToggle<CR>
nnoremap <F3> :TagbarToggle<CR>
