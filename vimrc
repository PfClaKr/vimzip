" vimzip
set nocompatible
let &packpath = $VIMZIP . ',' . $VIMRUNTIME
let &runtimepath = $VIMZIP . ',' . $VIMRUNTIME . ',' . $VIMRUNTIME . '/after'
let s:cache = expand('~/.cache/vimzip')
for s:d in ['undo', 'swap', 'sessions', 'tags', 'systags', 'words']
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
" exact-case tag lookups can binary-search the sorted tags file (gd 540 ms -> 1 ms on LLVM)
set tagcase=match
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
  autocmd InsertLeave,FocusLost,BufLeave * call s:AutoSave()
  " batch quick normal-mode edits (x, dd, ...) into one save, so linters and ctags run once
  autocmd TextChanged * call timer_stop(get(s:, 'save_timer', -1))
        \ | let s:save_timer = timer_start(1000, {-> mode() ==# 'n' ? s:AutoSave() : 0})
  autocmd FocusGained,BufEnter,CursorHold * silent! checktime
augroup END

" theme
if $COLORTERM =~# 'truecolor\|24bit'
  set termguicolors
endif
set background=dark
" use the terminal's own background so its edge padding blends in (no side bars in fullscreen)
augroup vimzip_bg
  autocmd!
  autocmd ColorScheme * for s:g in ['Normal', 'NonText', 'EndOfBuffer', 'SignColumn', 'LineNr', 'FoldColumn']
        \ | execute 'highlight' s:g 'ctermbg=NONE guibg=NONE' | endfor
augroup END
function! s:Highlights() abort
  highlight VimzipTreeIgnored ctermfg=242 guifg=#666666
  highlight VimzipBlame ctermfg=243 guifg=#767676 cterm=italic gui=italic
  highlight link VimzipTimelineFile Title
  highlight link VimzipTimelineAge VimzipBlame
  highlight link VimzipTimelineDirty Special
  highlight VimzipBar ctermfg=15 ctermbg=28 guifg=#ffffff guibg=#008700
  highlight VimzipModeNormal ctermfg=15 ctermbg=22 guifg=#ffffff guibg=#005f00
  highlight VimzipModeInsert ctermfg=15 ctermbg=25 guifg=#ffffff guibg=#005faf
  highlight VimzipModeVisual ctermfg=15 ctermbg=91 guifg=#ffffff guibg=#8700af
  highlight VimzipModeReplace ctermfg=15 ctermbg=124 guifg=#ffffff guibg=#af0000
  highlight VimzipTitle ctermfg=250 ctermbg=235 guifg=#bbbbbb guibg=#252526 cterm=NONE gui=NONE
  for g in ['StatusLine', 'StatusLineNC', 'StatusLineTerm', 'StatusLineTermNC']
    execute 'highlight' g 'ctermfg=250 ctermbg=235 guifg=#bbbbbb guibg=#252526 cterm=NONE gui=NONE'
  endfor
endfunction
autocmd ColorScheme * call s:Highlights()
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

" system headers: read-only, no linting
let g:ale_pattern_options = {'^/usr/': {'ale_enabled': 0}}
autocmd BufReadPost /usr/* setlocal readonly nomodifiable

" tags for the system headers the current C/C++ file includes (via cc -M)
function! s:SysTags() abort
  let cxx = &filetype ==# 'cpp'
  let cc = get(filter(cxx ? ['c++', 'g++', 'clang++'] : ['cc', 'gcc', 'clang'], 'executable(v:val)'), 0, '')
  if cc ==# '' | return 0 | endif
  let src = expand('%:p')
  let dirs = uniq(sort([expand('%:p:h'), expand('%:p:h:h') . '/include', getcwd(), getcwd() . '/include']))
  " the build's own flags (compile_commands.json from CMake etc.) via ALE, then guessed dirs
  let flags = exists('*ale#c#GetCFlags') ? ale#c#GetCFlags(bufnr(''), []) : ''
  let out = system(cc . ' -M -MG -w ' . flags . ' ' . join(map(dirs, '"-I" . shellescape(v:val)')) . ' ' . shellescape(src))
  let hdrs = filter(split(out), 'v:val =~# "^/" && v:val !=# src')
  if empty(hdrs) | return 0 | endif
  let f = s:cache . '/systags/' . substitute(src, '[/\\:]', '%', 'g') . '.tags'
  call system('ctags --languages=C,C++ --langmap=C:+.h --kinds-C=+px --kinds-C++=+px -L - -f '
        \ . shellescape(f), join(hdrs, "\n"))
  if v:shell_error | return 0 | endif
  let tags = empty(&l:tags) ? &g:tags : &l:tags
  if index(split(tags, ','), f) < 0
    let &l:tags = tags . ',' . escape(f, ',')
  endif
  return 1
endfunction

" go to definition: clangd if present, else project tags, else included system headers
function! s:GoDef() abort
  let c = &filetype =~# '^\(c\|cpp\)$'
  if s:lsp && c
    ALEGoToDefinition
    return
  endif
  let w = expand('<cword>')
  if w ==# '' | return | endif
  if empty(taglist('^' . w . '$')) && !(c && s:SysTags())
    echohl WarningMsg | echo 'No definition found: ' . w | echohl None
    return
  endif
  try
    execute 'tjump' w
  catch /E426\|E433/
    echohl WarningMsg | echo 'No definition found: ' . w | echohl None
  endtry
endfunction

" gutentags: keep tag files out of projects
let g:gutentags_cache_dir = s:cache . '/tags'
" index only source files (huge projects also skip test dirs): LLVM 474 MB -> 140 MB of tags
let g:gutentags_file_list_command = 'vimzip-files'

" gitgutter: its first git calls block while vim starts, so turn it on after the first screen
let g:gitgutter_enabled = 0

" GitLens-like: blame of the current line shown faintly after its end (Space gb toggles)
let g:vimzip_blame = get(g:, 'vimzip_blame', 1)
silent! call prop_type_add('vimzip_blame', {'highlight': 'VimzipBlame'})
function! s:Ago(t) abort
  let d = localtime() - a:t
  for [n, unit] in [[31536000, 'year'], [2592000, 'month'], [604800, 'week'], [86400, 'day'], [3600, 'hour'], [60, 'minute']]
    if d >= n
      let k = d / n
      return k . ' ' . unit . (k > 1 ? 's' : '') . ' ago'
    endif
  endfor
  return 'just now'
endfunction
function! s:BlameClear() abort
  if exists('s:blame_at') && bufexists(s:blame_at[0])
    silent! call prop_remove({'type': 'vimzip_blame', 'bufnr': s:blame_at[0], 'all': 1}, s:blame_at[1])
  endif
  unlet! s:blame_at
endfunction
function! s:Blame() abort
  call s:BlameClear()
  if !g:vimzip_blame || &buftype !=# '' || &modified || !filereadable(expand('%:p')) || empty(FugitiveGitDir())
    return
  endif
  if exists('s:blame_job') && job_status(s:blame_job) ==# 'run'
    call job_stop(s:blame_job)
  endif
  let [buf, lnum, out] = [bufnr(''), line('.'), []]
  let s:blame_job = job_start(['git', '-C', expand('%:p:h'), 'blame', '--porcelain', '-L', lnum . ',' . lnum, '--', expand('%:t')],
        \ {'err_io': 'null', 'out_cb': {_, l -> add(out, l)}, 'close_cb': {_ -> s:BlameShow(buf, lnum, out)}})
endfunction
function! s:BlameShow(buf, lnum, out) abort
  if empty(a:out) || bufnr('') != a:buf || line('.') != a:lnum || mode() !=# 'n'
    return
  endif
  let info = {}
  for l in a:out[1:]
    let m = matchlist(l, '^\(author\|author-time\|summary\) \(.*\)$')
    if !empty(m)
      let info[m[1]] = m[2]
    endif
  endfor
  let text = a:out[0] =~# '^0\{40}' ? 'You • Uncommitted changes'
        \ : get(info, 'author', '?') . ', ' . s:Ago(str2nr(get(info, 'author-time', '0'))) . ' • ' . get(info, 'summary', '')
  call prop_add(a:lnum, 0, {'type': 'vimzip_blame', 'bufnr': a:buf, 'text': text, 'text_align': 'after', 'text_padding_left': 4})
  let s:blame_at = [a:buf, a:lnum]
endfunction
" commit of the current line in a popup (Space gc)
function! s:CommitPopup() abort
  let out = systemlist('git -C ' . shellescape(expand('%:p:h')) . ' blame --porcelain -L ' . line('.') . ',' . line('.')
        \ . ' -- ' . shellescape(expand('%:t')))
  if v:shell_error || empty(out) | return | endif
  let sha = matchstr(out[0], '^\x\+')
  let lines = sha =~# '^0\+$' ? ['Uncommitted changes'] : systemlist('git -C ' . shellescape(expand('%:p:h'))
        \ . ' show --stat --no-color --format=' . shellescape('%h  %an, %ar%n%n%B') . ' ' . sha)
  call popup_atcursor(lines, {'border': [], 'padding': [0, 1, 0, 1], 'moved': 'any', 'maxheight': 20})
endfunction
" Timeline under the file tree, like VSCode (Space gt): commits that touched the current file.
" Enter opens that commit's change as a side-by-side diff; q in the diff goes back.
let s:tl = {'buf': -1, 'file': '', 'items': [], 'at': 0}
function! s:AgoShort(t) abort
  let d = localtime() - a:t
  for [n, unit] in [[31536000, 'y'], [2592000, 'mo'], [604800, 'w'], [86400, 'd'], [3600, 'h'], [60, 'm']]
    if d >= n | return (d / n) . unit | endif
  endfor
  return 'now'
endfunction
function! s:ToggleTimeline() abort
  if bufwinnr(s:tl.buf) > 0
    execute bufwinnr(s:tl.buf) . 'close'
    return
  endif
  call s:EditWin()
  let from = win_getid()
  if g:NERDTree.IsOpen()
    call win_gotoid(win_getid(g:NERDTree.GetWinNum()))
  else
    NERDTree
  endif
  belowright split
  execute 'resize' max([6, (&lines - &cmdheight - 3) * 2 / 5])
  if bufexists(s:tl.buf)
    execute 'buffer' s:tl.buf
  else
    enew
    setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nonumber norelativenumber
    setlocal nowrap nospell signcolumn=no cursorline winfixwidth
    silent file [Timeline]
    setfiletype vimziptimeline
    let s:tl.buf = bufnr('')
    nnoremap <buffer> <silent> <CR> :call <SID>TimelineOpen()<CR>
    nnoremap <buffer> <silent> o :call <SID>TimelineOpen()<CR>
    nnoremap <buffer> <silent> <2-LeftMouse> :call <SID>TimelineOpen()<CR>
  endif
  call win_gotoid(from)
  let s:tl.at = 0
  call s:TimelineUpdate()
endfunction
function! s:TimelineUpdate() abort
  if bufwinnr(s:tl.buf) < 0 || &buftype !=# '' || expand('%') =~# '^\a\+://'
    return
  endif
  let f = expand('%:p')
  if f ==# s:tl.file && localtime() - s:tl.at < 2
    return
  endif
  let s:tl.at = localtime()
  if !filereadable(f)
    return
  endif
  if empty(FugitiveGitDir())
    call s:TimelineRender(f, [])
    return
  endif
  let [dir, name, out] = [shellescape(fnamemodify(f, ':h')), shellescape(fnamemodify(f, ':t')), []]
  let cmd = 'cd ' . dir . ' && git status --porcelain -- ' . name . '; echo @@; git log --follow -n 300 --name-only'
        \ . ' --format=%x01%h%x09%at%x09%an%x09%s -- ' . name
  call job_start(['sh', '-c', cmd], {'err_io': 'null', 'out_cb': {_, l -> add(out, l)},
        \ 'close_cb': {_ -> s:TimelineRender(f, out)}})
endfunction
function! s:TimelineRender(file, out) abort
  if !bufexists(s:tl.buf)
    return
  endif
  let sep = index(a:out, '@@')
  let [items, lines] = [[], [fnamemodify(a:file, ':t')]]
  if sep > 0 && a:out[0] !~# '^??'
    call add(items, {'sha': ''})
    call add(lines, '*    Uncommitted changes')
  endif
  for l in a:out[sep + 1 :]
    if l[0] ==# "\x01"
      let [sha, t, author; subject] = split(l[1:], "\t", 1)
      call add(items, {'sha': sha, 'path': ''})
      call add(lines, printf('%-4s %s', s:AgoShort(str2nr(t)), join(subject, "\t")))
    elseif l !=# '' && !empty(items) && items[-1].sha !=# ''
      let items[-1].path = l
    endif
  endfor
  if len(lines) == 1
    call add(lines, filereadable(a:file) ? '     No history yet' : '     No file')
  endif
  call setbufvar(s:tl.buf, '&modifiable', 1)
  silent call deletebufline(s:tl.buf, 1, '$')
  call setbufline(s:tl.buf, 1, lines)
  call setbufvar(s:tl.buf, '&modifiable', 0)
  let [s:tl.file, s:tl.items] = [a:file, items]
endfunction
function! s:TimelineOpen() abort
  let i = line('.') - 2
  if i < 0 || i >= len(s:tl.items)
    return
  endif
  let it = s:tl.items[i]
  let w = bufwinid(s:tl.file)
  if w < 0
    wincmd p
    call s:EditWin()
    execute 'edit' fnameescape(s:tl.file)
    let w = win_getid()
  endif
  call win_gotoid(w)
  let s:tl.diffwin = w
  try
    if it.sha ==# ''
      Gvdiffsplit HEAD
    else
      execute 'Gedit' it.sha . ':' . (it.path !=# '' ? it.path : '%')
      execute 'leftabove Gvdiffsplit' it.sha . '~1'
    endif
  catch
    echohl WarningMsg | echo 'Timeline: ' . v:exception | echohl None
  endtry
  " old on the left, new on the right, like VSCode; past versions stay out of the tab bar
  for d in filter(range(1, winnr('$')), 'getwinvar(v:val, "&diff")')
    call win_execute(win_getid(d), 'nnoremap <buffer> <silent> q :call <SID>TimelineCloseDiff()<CR>')
    if bufname(winbufnr(d)) =~# '^fugitive://'
      call setbufvar(winbufnr(d), '&buflisted', 0)
    endif
  endfor
  call lightline#update()
endfunction
function! s:TimelineCloseDiff() abort
  diffoff!
  for w in reverse(range(1, winnr('$')))
    if win_getid(w) != get(s:tl, 'diffwin', 0) && bufname(winbufnr(w)) =~# '^fugitive://'
      execute w . 'close'
    endif
  endfor
  if win_gotoid(get(s:tl, 'diffwin', 0))
    execute 'edit' fnameescape(s:tl.file)
    silent! nunmap <buffer> q
  endif
  for b in getbufinfo()
    if b.name =~# '^fugitive://' && empty(b.windows)
      execute 'silent! bwipeout' b.bufnr
    endif
  endfor
endfunction
" quit when only the tree and timeline are left
function! s:QuitIfOnlyPanels() abort
  for w in range(1, winnr('$'))
    let b = winbufnr(w)
    if getbufvar(b, '&filetype') !=# 'nerdtree' && b != s:tl.buf
      return
    endif
  endfor
  qall
endfunction

augroup vimzip_blame
  autocmd!
  autocmd BufEnter,BufWritePost * call s:TimelineUpdate()
  autocmd FileType vimziptimeline syntax match VimzipTimelineFile /\%1l.*/
        \ | syntax match VimzipTimelineAge /^\%>1l\S\+/ | syntax match VimzipTimelineDirty /^\*.*/
  autocmd CursorHold * call s:Blame()
  autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave * if exists('s:blame_at') | call s:BlameClear() | endif
augroup END

" fzf
let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --glob "!.git"'

" project search: run rg only while there is a query (fzf.vim's :RG greps every line on an empty one)
function! s:Find(query, bang) abort
  let rg = 'rg --column --line-number --no-heading --color=always --smart-case --hidden --glob "!.git" -- '
  let reload = '[ -z {q} ] || ' . rg . '{q} || :'
  call fzf#vim#grep(':', fzf#vim#with_preview({'options': ['--disabled', '--query', a:query,
    \ '--prompt', 'Find> ', '--bind', 'start:reload:' . reload, '--bind', 'change:reload:' . reload]}), a:bang)
endfunction
command! -bang -nargs=* Find call s:Find(<q-args>, <bang>0)

" nerdtree
let g:NERDTreeHijackNetrw = 0
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = ['^\.git$']
let g:NERDTreeWinSize = 30
let g:NERDTreeStatusline = -1
let g:tagbar_no_status_line = 1
let g:NERDTreeGitStatusConcealBrackets = 1
let g:NERDTreeGitStatusShowIgnored = 1
let g:NERDTreeGitStatusIndicatorMapCustom = {
  \ 'Modified': 'M', 'Staged': 'A', 'Untracked': 'U', 'Renamed': 'R', 'Unmerged': 'C',
  \ 'Deleted': 'D', 'Dirty': '~', 'Ignored': nr2char(160), 'Clean': ' ', 'Unknown': '?'}
" gitignored entries are drawn dimmed like VSCode; their indicator is a no-break space, so it
" shows as blank yet can be matched
function! s:TreeIgnoredSyntax() abort
  execute 'syntax match VimzipTreeIgnored #\[ *\%d160 *\]\%d' . char2nr(g:NERDTreeNodeDelimiter) . '.*#'
        \ . ' contains=NERDTreeFlags containedin=NERDTreeFile,NERDTreeExecFile,NERDTreeDir,NERDTreeLinkFile,NERDTreeLinkDir'
endfunction

" NERDTree sorts with a vimscript comparator (N log N calls): a 5500-file folder took 14 s.
" Sort on one precomputed key per entry with vim's built-in sort instead; same order.
function! s:NERDTreeSortChildren() dict
  if g:NERDTreeNaturalSort || join(g:NERDTreeSortOrder) =~# '\[\['
    return call(s:nerdtree_sort, [], self)
  endif
  if count(g:NERDTreeSortOrder, '*') < 1
    call add(g:NERDTreeSortOrder, '*')
  endif
  let kids = self.children
  let keys = []
  for i in range(len(kids))
    let k = kids[i].path.getSortKey()
    call add(keys, printf('%04d', k[0]) . "\t" . k[-1] . "\t" . printf('%08d', i))
  endfor
  let self.children = map(sort(keys), {_, k -> kids[str2nr(matchstr(k, '\d\+$'))]})
  let g:NERDTreeOldSortOrder = g:NERDTreeSortOrder
endfunction
" It also renders by appending to one string, which copies it once per line; collect a list.
function! s:NERDTreeRender(depth, drawText) dict
  let out = []
  call s:NERDTreeRenderInto(self, a:depth, a:drawText, out)
  return empty(out) ? '' : join(out, "\n") . "\n"
endfunction
function! s:NERDTreeRenderInto(node, depth, drawText, out) abort
  if a:drawText ==# 1
    call add(a:out, repeat('  ', a:depth - 1)
          \ . (a:node.path.isDirectory || g:NERDTreeDirArrowExpandable ==# '' ? '' : '  ') . a:node.displayString())
  endif
  if a:node.path.isDirectory ==# 1 && a:node.isOpen ==# 1
    let kids = a:node.getVisibleChildren()
    if a:node.isCascadable() && a:depth > 0
      call s:NERDTreeRenderInto(kids[0], a:depth, 0, a:out)
    else
      for k in kids
        call s:NERDTreeRenderInto(k, a:depth + 1, 1, a:out)
      endfor
    endif
  endif
endfunction
function! s:FastNERDTree() abort
  if exists('g:NERDTreeDirNode') && exists('g:NERDTreeFileNode') && !exists('s:nerdtree_sort')
    let s:nerdtree_sort = g:NERDTreeDirNode.sortChildren
    let g:NERDTreeDirNode.sortChildren = function('s:NERDTreeSortChildren')
    let g:NERDTreeDirNode._renderToString = function('s:NERDTreeRender')
    let g:NERDTreeFileNode._renderToString = function('s:NERDTreeRender')
  endif
endfunction

" termdebug
let g:termdebug_config = {'wide': 1}

" lightline draws only the tab bar; the status bar is ours (below)
let g:lightline = {
  \ 'colorscheme': 'vimzip',
  \ 'enable': {'statusline': 0, 'tabline': 1},
  \ 'separator': {'left': '', 'right': ''}, 'subseparator': {'left': '', 'right': ''},
  \ 'tabline': {'left': [['buffers']], 'right': [[]]},
  \ 'component_expand': {'buffers': 'lightline#bufferline#buffers'},
  \ 'component_type': {'buffers': 'tabsel'}}
let g:lightline#bufferline#clickable = 1
let g:lightline#bufferline#min_buffer_count = 1
let g:lightline.component_raw = {'buffers': 1}

" One status bar for the whole screen in Vim green (vim has no laststatus=3 as Neovim does).
" The status lines along the bottom edge together draw the bar for the current window: its
" left part in the leftmost one, its right part in the rightmost, plain blue in between.
" A window with another window below it gets a thin title instead (EXPLORER, TIMELINE, file).
set laststatus=2 statusline=%!VimzipStatus()
" the bar may sit in another window's status line, so redraw them all as the cursor or mode changes
augroup vimzip_status
  autocmd!
  autocmd CursorMoved,CursorMovedI,ModeChanged,WinEnter,BufEnter,TextChanged,TextChangedI * redrawstatus!
augroup END
let s:modes = {'n': ['NORMAL', 'Normal'], 'i': ['INSERT', 'Insert'], 'R': ['REPLACE', 'Replace'],
  \ 'v': ['VISUAL', 'Visual'], 'V': ['V-LINE', 'Visual'], "\<C-v>": ['V-BLOCK', 'Visual'],
  \ 's': ['SELECT', 'Visual'], 'S': ['S-LINE', 'Visual'], 'c': ['COMMAND', 'Normal'], 't': ['TERMINAL', 'Insert']}
let s:languages = {'c': 'C', 'cpp': 'C++', 'python': 'Python', 'sh': 'Shell Script', 'bash': 'Shell Script',
  \ 'zsh': 'Shell Script', 'make': 'Makefile', 'cmake': 'CMake', 'markdown': 'Markdown', 'vim': 'Vim Script',
  \ 'json': 'JSON', 'yaml': 'YAML', 'javascript': 'JavaScript', 'typescript': 'TypeScript', 'go': 'Go',
  \ 'rust': 'Rust', 'java': 'Java', 'lua': 'Lua', 'html': 'HTML', 'css': 'CSS', 'xml': 'XML', 'sql': 'SQL',
  \ 'dockerfile': 'Dockerfile', 'gitcommit': 'Git Commit', 'gitignore': 'Ignore', 'text': 'Plain Text'}
function! VimzipProblems() abort
  if &buftype !=# '' || !exists('g:loaded_ale') | return '' | endif
  let c = ale#statusline#Count(bufnr(''))
  let e = c.error + c.style_error
  return printf('E %d  W %d', e, c.total - e)
endfunction
function! s:Title(w) abort
  let b = winbufnr(a:w)
  let ft = getbufvar(b, '&filetype')
  return ft ==# 'nerdtree' ? 'EXPLORER' : ft ==# 'vimziptimeline' ? 'TIMELINE' : ft ==# 'tagbar' ? 'OUTLINE'
        \ : getbufvar(b, '&buftype') ==# 'terminal' ? 'TERMINAL'
        \ : (bufname(b) !=# '' ? fnamemodify(bufname(b), ':t') : '[No Name]') . (getbufvar(b, '&modified') ? ' +' : '')
endfunction
function! s:Esc(text) abort
  return substitute(a:text, '%', '%%', 'g')
endfunction
" evaluated in the current window, for the window g:statusline_winid
function! VimzipStatus() abort
  let w = g:statusline_winid
  let [row, col] = win_screenpos(w)
  if row + winheight(w) < &lines - &cmdheight
    return '%#VimzipTitle# ' . s:Esc(s:Title(w))
  endif
  let [isleft, isright] = [col == 1, col + winwidth(w) > &columns]
  let left = ''
  if isleft
    let [name, group] = get(s:modes, mode(), [toupper(mode()), 'Normal'])
    let left = '%#VimzipMode' . group . '# ' . name . ' %#VimzipBar#'
    for item in [exists('*FugitiveHead') ? FugitiveHead() : '', VimzipProblems()]
      let left .= item !=# '' ? '  ' . s:Esc(item) : ''
    endfor
  endif
  let right = ''
  if isright && &buftype ==# ''
    " drop the least useful items first when the space is short
    let room = winwidth(w) - (isleft ? strwidth(substitute(left, '%#\w\+#', '', 'g')) : 0) - 2
    let items = [printf('Ln %d, Col %d', line('.'), virtcol('.')),
          \ &expandtab ? 'Spaces: ' . shiftwidth() : 'Tab Size: ' . &tabstop,
          \ toupper(&fileencoding !=# '' ? &fileencoding : &encoding),
          \ get({'unix': 'LF', 'dos': 'CRLF', 'mac': 'CR'}, &fileformat, &fileformat),
          \ &filetype ==# '' ? 'Plain Text' : get(s:languages, &filetype, toupper(&filetype[0]) . &filetype[1:])]
    for drop in [1, 2, 3, 4]
      if strwidth(join(filter(copy(items), 'v:val !=# ""'), '  ')) <= room | break | endif
      let items[drop] = ''
      if drop == 2 | let items[3] = '' | endif
    endfor
    let right = s:Esc(join(filter(items, 'v:val !=# ""'), '  ')) . ' '
  endif
  return '%#VimzipBar#' . left . '%=' . right
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

" :q closes the current tab (buffer) like VSCode while other tabs are open; the last one quits.
" Splits and special windows (tree, terminal, help, ...) keep the usual :q.
function! s:Quit(bang) abort
  let editwins = len(filter(range(1, winnr('$')), 'getwinvar(v:val, "&buftype") ==# ""'))
  if &buftype !=# '' || editwins > 1 || len(getbufinfo({'buflisted': 1})) < 2 || (&modified && !a:bang)
    execute 'quit' . (a:bang ? '!' : '')
    return
  endif
  let b = bufnr('')
  if a:bang
    setlocal nomodified  " discard: keep autosave (on leaving the buffer) from writing it
  endif
  bprevious
  execute 'bdelete' . (a:bang ? '!' : '') b
endfunction
command! -bang VimzipQuit call s:Quit(<bang>0)
command! -bang VimzipWriteQuit update | call s:Quit(<bang>0)
cnoreabbrev <expr> q getcmdtype() ==# ':' && getcmdline() ==# 'q' ? 'VimzipQuit' : 'q'
cnoreabbrev <expr> wq getcmdtype() ==# ':' && getcmdline() ==# 'wq' ? 'VimzipWriteQuit' : 'wq'
cnoreabbrev <expr> x getcmdtype() ==# ':' && getcmdline() ==# 'x' ? 'VimzipWriteQuit' : 'x'

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
  if bufexists(t) && term_getstatus(t) =~# 'running'
    execute 'botright sbuffer' t
    resize 12
  else
    botright terminal ++rows=12 ++kill=hup ++close
    call s:TermKeys()
    let s:term = bufnr('')
  endif
endfunction

" AI agent on the right (Ctrl+Alt+I / Space a): g:vimzip_ai, $VIMZIP_AI, or the first agent CLI found
function! s:ToggleAi() abort
  let t = get(s:, 'ai', -1)
  let w = bufwinnr(t)
  if w > 0
    execute w . 'hide'
    call win_gotoid(get(s:, 'ai_from', 0))
    return
  endif
  let cmd = get(g:, 'vimzip_ai', $VIMZIP_AI)
  if cmd ==# ''
    let cmd = get(filter(['claude', 'codex', 'gemini', 'aider', 'opencode'], 'executable(v:val)'), 0, '')
  endif
  if cmd ==# '' && !bufexists(t)
    echohl WarningMsg | echo 'No AI agent found. Set one, e.g.: export VIMZIP_AI=claude' | echohl None
    return
  endif
  call s:EditWin()
  let s:ai_from = win_getid()
  let width = max([60, &columns * 2 / 5])
  if bufexists(t) && term_getstatus(t) =~# 'running'
    execute 'botright vertical sbuffer' t
    execute 'vertical resize' width
  else
    execute 'botright vertical' width 'new'
    let blank = bufnr('')
    let s:ai = term_start([&shell, &shellcmdflag, cmd], {'curwin': 1, 'term_kill': 'hup',
          \ 'term_finish': 'close', 'term_name': 'AI: ' . cmd})
    if bufexists(blank) && blank != s:ai
      execute 'silent! bwipeout' blank
    endif
  endif
endfunction

" keep the open tree pointed at the current file, like VSCode's explorer (focus stays in the editor)
function! s:RevealInTree() abort
  if &buftype !=# '' || !exists('g:NERDTree') || !g:NERDTree.IsOpen()
    return
  endif
  let f = expand('%:p')
  let root = g:NERDTree.ForCurrentTab().root.path.str()
  if f ==# get(s:, 'revealed', '') || !filereadable(f) || stridx(f, root . '/') != 0
    return
  endif
  let s:revealed = f
  let w = win_getid()
  silent! NERDTreeFind
  call win_gotoid(w)
endfunction

" file tree like VSCode Ctrl+Shift+E: open and focus, focus, or close
function! s:Explorer() abort
  if exists('b:NERDTree')
    NERDTreeClose
  elseif g:NERDTree.IsOpen()
    NERDTreeFocus
  elseif &buftype ==# '' && stridx(expand('%:p'), getcwd() . '/') == 0
    NERDTreeFind
  else
    NERDTreeFocus
  endif
endfunction

" Ctrl+N: also offer words from the git project's source files. rg collects them in the background
" into a sorted file and each completion greps it, so vim's memory stays flat on huge projects.
let s:src_types = ' -t c -t cpp -t h -t py -t sh -t cmake -t make -t go -t rust -t java -t js -t ts -t lua -t vim -t md'
function! s:Words() abort
  if (exists('s:words_job') && job_status(s:words_job) ==# 'run') || localtime() - get(s:, 'words_at', 0) < 60
    return
  endif
  if !executable('rg') | return | endif
  let s:words_at = localtime()
  let f = s:cache . '/words/' . substitute(getcwd(), '[/\\:]', '%', 'g') . '.txt'
  if filereadable(f)
    call s:UseWords(f)
  endif
  let cmd = 'root=$(git -C ' . shellescape(getcwd()) . ' rev-parse --show-toplevel 2>/dev/null) || exit 1; '
        \ . 'rg --no-filename --no-line-number --only-matching --max-filesize 1M' . s:src_types
        \ . ' "[A-Za-z_][A-Za-z0-9_]{2,39}\b" "$root" | LC_ALL=C sort -u > ' . shellescape(f . '.tmp')
        \ . ' && mv ' . shellescape(f . '.tmp') . ' ' . shellescape(f)
  let s:words_job = job_start(['sh', '-c', cmd], {'exit_cb': {j, s -> s ? 0 : s:UseWords(f)}})
endfunction
function! s:UseWords(f) abort
  let s:words_file = a:f
  if stridx(&complete, 'FVimzipWords') < 0
    set complete+=FVimzipWords
  endif
endfunction
function! VimzipWords(findstart, base) abort
  if a:findstart
    return match(col('.') > 1 ? getline('.')[: col('.') - 2] : '', '\k*$')
  endif
  if len(a:base) < 2 || !filereadable(get(s:, 'words_file', ''))
    return []
  endif
  let hits = systemlist('grep -m 200 ' . (&ignorecase ? '-i ' : '') . '-e '
        \ . shellescape('^' . escape(a:base, '.*[]\^$')) . ' ' . shellescape(s:words_file))
  return map(filter(hits, 'v:val !=# a:base'), {_, w -> {'word': w, 'menu': '[project]'}})
endfunction

" extra terminal next to the current window (below or right)
function! s:NewTerm(vert) abort
  if exists('b:NERDTree')
    wincmd p
  endif
  execute (a:vert ? 'vertical ' : '') . 'terminal ++kill=hup ++close'
  call s:TermKeys()
endfunction

" paste like VSCode's terminal: copy with Ctrl+w N (or a mouse drag) then y / Ctrl+C,
" paste with Ctrl+V, or p while still selecting. Only in vimzip's own shells: the AI panel
" (image paste) and fzf popups use Ctrl+V themselves.
function! s:TermKeys() abort
  tnoremap <buffer> <silent> <C-v> <C-w>""
  nnoremap <buffer> <silent> p i<C-w>""
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

" switch project in place (Space p / :Project): save this one's tabs, close its tabs, terminals
" and AI panel, then open the other folder and restore its tabs
function! s:OpenProject(dir) abort
  let dir = fnamemodify(expand(trim(a:dir)), ':p')
  let dir = dir =~# '.\/$' ? dir[:-2] : dir
  if !isdirectory(dir)
    echohl WarningMsg | echo 'Not a folder: ' . a:dir | echohl None
    return
  endif
  silent! wall
  call s:Save()
  for b in term_list()
    execute 'silent! bwipeout!' b
  endfor
  silent! %bwipeout
  execute 'cd' fnameescape(dir)
  let s:session = s:SessionFile()
  if filereadable(s:session)
    execute 'silent! source' fnameescape(s:session)
  endif
  execute 'NERDTree' fnameescape(getcwd())
  wincmd p
  unlet! s:words_file
  let s:words_at = 0
  call s:Words()
  call lightline#update()
endfunction

" recent projects = folders that have a saved session, newest first
function! s:RecentProjects() abort
  let files = glob(s:cache . '/sessions/*.vim', 0, 1)
  call sort(files, {a, b -> getftime(b) - getftime(a)})
  let dirs = map(files, {_, f -> substitute(fnamemodify(f, ':t:r'), '%', '/', 'g')})
  return map(filter(dirs, {_, d -> isdirectory(d) && d !=# getcwd()}), {_, d -> fnamemodify(d, ':~')})
endfunction
function! s:PickProject() abort
  call fzf#run(fzf#wrap({'source': s:RecentProjects(), 'sink': function('s:OpenProject'),
        \ 'options': ['--prompt', 'Project> ', '--header', 'recent projects (or type a path)',
        \             '--bind', 'enter:accept-or-print-query']}))
endfunction
command! -nargs=? -complete=dir Project if <q-args> ==# '' | call s:PickProject() | else | call s:OpenProject(<q-args>) | endif

function! s:TermOpen(buf) abort
  call setbufvar(a:buf, '&buflisted', 0)
  if bufnr('') == a:buf
    setlocal nonumber nocursorline signcolumn=no
  endif
endfunction

augroup vimzip
  autocmd!
  autocmd VimEnter * call s:FastNERDTree()
  autocmd VimEnter * ++nested call s:Start()
  autocmd VimEnter * call timer_start(0, {-> execute('silent! GitGutterEnable')})
  autocmd VimEnter,BufWritePost * call s:Words()
  autocmd VimLeavePre * call s:Save()
  autocmd TerminalOpen * call s:TermOpen(str2nr(expand('<abuf>')))
  autocmd User ALELintPost redrawstatus!
  autocmd BufEnter * call s:QuitIfOnlyPanels()
  autocmd BufEnter * call s:RevealInTree()
  autocmd FileType nerdtree call s:TreeIgnoredSyntax()
  " long names wrap onto the next line inside the tree instead of needing a sideways scroll
  autocmd FileType nerdtree setlocal wrap nolinebreak breakindent breakindentopt=shift:3
augroup END

" keys
nnoremap <silent> <C-p> :call <SID>Buf('Files')<CR>
nnoremap <silent> <C-S-f> :call <SID>Buf('Find')<CR>
nnoremap <silent> <leader>f :call <SID>Buf('Find')<CR>
nnoremap <silent> <leader>b :call <SID>Buf('Buffers')<CR>
nnoremap <silent> <leader>p :call <SID>PickProject()<CR>
nnoremap <silent> <leader>t :call <SID>Buf('Tags')<CR>
nnoremap <silent> <Tab> :call <SID>Buf('bnext')<CR>
nnoremap <silent> <S-Tab> :call <SID>Buf('bprevious')<CR>
nnoremap <silent> <leader>q :call <SID>CloseBuf()<CR>
nnoremap <silent> <C-s> :update<CR>
inoremap <silent> <C-s> <C-o>:update<CR>
xnoremap <silent> <C-s> <Esc>:update<CR>
xnoremap <C-c> y
nnoremap <silent> <F2> :NERDTreeToggle<CR>
nnoremap <silent> <C-S-e> :call <SID>Explorer()<CR>
tnoremap <silent> <C-S-e> <C-w>:call <SID>Explorer()<CR>
nnoremap <silent> <C-M-i> :call <SID>ToggleAi()<CR>
tnoremap <silent> <C-M-i> <C-w>:call <SID>ToggleAi()<CR>
nnoremap <silent> <leader>a :call <SID>ToggleAi()<CR>
nnoremap <silent> <F3> :TagbarToggle<CR>
nnoremap <silent> <F4> :call <SID>ToggleTerm()<CR>
tnoremap <silent> <F4> <C-w>:call <SID>ToggleTerm()<CR>
nnoremap <silent> <leader>- :call <SID>NewTerm(0)<CR>
nnoremap <silent> <leader>\ :call <SID>NewTerm(1)<CR>
tnoremap <silent> <C-w>n <C-w>:call <SID>NewTerm(0)<CR>
tnoremap <silent> <C-w>\ <C-w>:call <SID>NewTerm(1)<CR>
" windows
nnoremap <silent> <leader>s :split<CR>
nnoremap <silent> <leader>v :vsplit<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <silent> <leader>e :ALEDetail<CR>
" git (GitLens-like)
nnoremap <silent> <leader>gb :let g:vimzip_blame = !g:vimzip_blame <Bar> call <SID>Blame()<CR>
nnoremap <silent> <leader>gB :Git blame<CR>
nnoremap <silent> <leader>gc :call <SID>CommitPopup()<CR>
nnoremap <silent> <leader>gh :GV!<CR>
xnoremap <silent> <leader>gh :GV<CR>
nnoremap <silent> <leader>gl :GV<CR>
nnoremap <silent> <leader>gs :Git<CR>
nnoremap <silent> <leader>gt :call <SID>ToggleTimeline()<CR>
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

" personal overrides
if filereadable(expand('~/.config/vimzip/vimrc'))
  execute 'source' fnameescape(expand('~/.config/vimzip/vimrc'))
endif
