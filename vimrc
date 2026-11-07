" vimzip
set nocompatible
let &packpath = $VIMZIP . ',' . $VIMRUNTIME
let &runtimepath = $VIMZIP . ',' . $VIMRUNTIME . ',' . $VIMRUNTIME . '/after'
let s:cache = expand('~/.cache/vimzip')
for s:d in ['undo', 'swap', 'sessions', 'tags']
  silent! call mkdir(s:cache . '/' . s:d, 'p')
endfor

" built-in packages
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1
packadd! comment
packadd! editorconfig
packadd! matchit
packadd! termdebug
packadd osc52

filetype plugin indent on
syntax on

" basics
set encoding=utf-8 fileencodings=ucs-bom,utf-8,cp949,latin1
set autoindent smarttab tabstop=4 shiftwidth=4
set number cursorline signcolumn=yes scrolloff=5 showmatch
set hidden autoread mouse=a belloff=all splitright splitbelow
set laststatus=2 showtabline=2 noshowmode showcmd ruler
set incsearch hlsearch ignorecase smartcase
set backspace=indent,eol,start wildmenu wildoptions=pum display=lastline
set ttimeout ttimeoutlen=50 updatetime=300
set completeopt=menuone,popup noautocomplete
set undofile
let &undodir = s:cache . '/undo'
let &directory = s:cache . '/swap//'

" autosave on leaving insert mode, after normal-mode changes, and on focus/buffer change
function! s:AutoSave() abort
  if &modified && &buftype ==# '' && &modifiable && !&readonly && expand('%') !=# ''
        \ && &filetype !~# '^\(gitcommit\|gitrebase\)$'
    silent! update
  endif
endfunction
augroup vimzip_autosave
  autocmd!
  autocmd InsertLeave,TextChanged,FocusLost,BufLeave * call s:AutoSave()
  autocmd FocusGained,BufEnter,CursorHold * silent! checktime
augroup END

" theme
if $COLORTERM =~# 'truecolor\|24bit'
  set termguicolors
endif
set background=dark
silent! colorscheme habamax

" clipboard over SSH (OSC 52): yanks also go to the local clipboard
set clipmethod=osc52
let g:osc52_disable_paste = 1
augroup vimzip_clip
  autocmd!
  autocmd TextYankPost * if v:event.operator ==# 'y' && v:event.regname ==# ''
        \ && v:clipmethod =~# 'osc52' | call setreg('+', getreg('"'), getregtype('"')) | endif
augroup END

let mapleader = ' '

" ALE: clangd when available, else the system C compiler
let s:lsp = executable('clangd')
let g:ale_linters = {
  \ 'c': s:lsp ? ['clangd'] : ['cc'],
  \ 'cpp': s:lsp ? ['clangd'] : ['cc'],
  \ 'sh': ['shellcheck']}
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_completion_enabled = 0
if s:lsp
  autocmd FileType c,cpp setlocal omnifunc=ale#completion#OmniFunc
endif

function! s:GoDef() abort
  if s:lsp && &filetype =~# '^\(c\|cpp\)$'
    ALEGoToDefinition
  else
    execute "normal! \<C-]>"
  endif
endfunction

" gutentags: keep tag files out of projects
let g:gutentags_cache_dir = s:cache . '/tags'

" fzf
let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git"'

" nerdtree
let g:NERDTreeHijackNetrw = 0
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = ['^\.git$']
let g:NERDTreeWinSize = 30

" termdebug
let g:termdebug_config = {'wide': 1}

" lightline + buffer tabs
let g:lightline = {
  \ 'colorscheme': 'wombat',
  \ 'active': {
  \   'left': [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
  \   'right': [['ale', 'lineinfo'], ['percent'], ['fileformat', 'fileencoding', 'filetype']]},
  \ 'tabline': {'left': [['buffers']], 'right': [[]]},
  \ 'component_expand': {'buffers': 'lightline#bufferline#buffers'},
  \ 'component_type': {'buffers': 'tabsel'},
  \ 'component_function': {'gitbranch': 'FugitiveHead', 'ale': 'VimzipAle'}}
let g:lightline#bufferline#clickable = 1
let g:lightline#bufferline#min_buffer_count = 1
let g:lightline.component_raw = {'buffers': 1}
function! VimzipAle() abort
  if !exists('g:loaded_ale') | return '' | endif
  let c = ale#statusline#Count(bufnr(''))
  let e = c.error + c.style_error
  return c.total ? printf('E:%d W:%d', e, c.total - e) : ''
endfunction

" switch/close buffers without touching the tree or terminal windows
function! s:EditWin() abort
  if &buftype !=# '' || exists('b:NERDTree')
    wincmd p
  endif
endfunction
function! s:Buf(cmd) abort
  call s:EditWin()
  execute a:cmd
endfunction
function! s:CloseBuf() abort
  call s:EditWin()
  let b = bufnr('')
  if len(getbufinfo({'buflisted': 1})) > 1
    bprevious
  else
    enew
  endif
  execute 'silent! bdelete' b
endfunction

" bottom terminal panel
function! s:ToggleTerm() abort
  let t = get(s:, 'term', -1)
  let w = bufwinnr(t)
  if w > 0
    execute w . 'hide'
    call win_gotoid(get(s:, 'term_from', 0))
    return
  endif
  call s:EditWin()
  let s:term_from = win_getid()
  if bufexists(t)
    execute 'botright sbuffer' t
    resize 12
  else
    botright terminal ++rows=12 ++kill=hup
    let s:term = bufnr('')
  endif
endfunction

" per-folder session, used when started as `vim <dir>`
function! s:SessionFile() abort
  return s:cache . '/sessions/' . substitute(getcwd(), '[/\\:]', '%', 'g') . '.vim'
endfunction
set sessionoptions=buffers,curdir,folds,tabpages,winsize

function! s:Start() abort
  if argc() != 1 || !isdirectory(argv(0))
    return
  endif
  let dirbuf = bufnr('')
  execute 'cd' fnameescape(argv(0))
  silent! argdelete *
  let s:session = s:SessionFile()
  if filereadable(s:session)
    execute 'silent! source' fnameescape(s:session)
  else
    enew
  endif
  if bufexists(dirbuf) && bufnr('') != dirbuf
    execute 'silent! bwipeout' dirbuf
  endif
  NERDTree
  wincmd p
endfunction

function! s:Save() abort
  if !exists('s:session') | return | endif
  silent! NERDTreeClose
  for w in reverse(range(1, winnr('$')))
    if winnr('$') > 1 && getwinvar(w, '&buftype') !=# ''
      execute w . 'close'
    endif
  endfor
  execute 'mksession!' fnameescape(s:session)
endfunction

function! s:TermOpen(buf) abort
  call setbufvar(a:buf, '&buflisted', 0)
  if bufnr('') == a:buf
    setlocal nonumber nocursorline signcolumn=no
  endif
endfunction

augroup vimzip
  autocmd!
  autocmd VimEnter * ++nested call s:Start()
  autocmd VimLeavePre * call s:Save()
  autocmd TerminalOpen * call s:TermOpen(str2nr(expand('<abuf>')))
  autocmd User ALELintPost call lightline#update()
  autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
augroup END

" keys
nnoremap <silent> <C-p> :call <SID>Buf('Files')<CR>
nnoremap <silent> <C-S-f> :call <SID>Buf('RG')<CR>
nnoremap <silent> <leader>f :call <SID>Buf('RG')<CR>
nnoremap <silent> <leader>b :call <SID>Buf('Buffers')<CR>
nnoremap <silent> <leader>t :call <SID>Buf('Tags')<CR>
nnoremap <silent> <Tab> :call <SID>Buf('bnext')<CR>
nnoremap <silent> <S-Tab> :call <SID>Buf('bprevious')<CR>
nnoremap <silent> <leader>q :call <SID>CloseBuf()<CR>
nnoremap <silent> <C-s> :update<CR>
inoremap <silent> <C-s> <C-o>:update<CR>
xnoremap <silent> <C-s> <Esc>:update<CR>
xnoremap <C-c> y
nnoremap <silent> <F2> :NERDTreeToggle<CR>
nnoremap <silent> <F3> :TagbarToggle<CR>
nnoremap <silent> <F4> :call <SID>ToggleTerm()<CR>
tnoremap <silent> <F4> <C-w>:call <SID>ToggleTerm()<CR>
nnoremap <silent> <F12> :call <SID>GoDef()<CR>
nnoremap <silent> gd :call <SID>GoDef()<CR>
if s:lsp
  nnoremap <silent> gr :ALEFindReferences<CR>
  nnoremap <silent> K :ALEHover<CR>
endif
nmap ]e <Plug>(ale_next_wrap)
nmap [e <Plug>(ale_previous_wrap)
" debugger (termdebug): F5 start/continue, F9 breakpoint, F10 over, F11 step
function! s:Debug() abort
  if exists(':RunOrContinue') == 2
    RunOrContinue
  else
    call feedkeys(':TermdebugCommand ', 'n')
  endif
endfunction
nnoremap <silent> <F5> :call <SID>Debug()<CR>
nnoremap <silent> <F9> :silent! ToggleBreak<CR>
nnoremap <silent> <F10> :silent! Over<CR>
nnoremap <silent> <F11> :silent! Step<CR>
nnoremap <silent> <S-F11> :silent! Finish<CR>
