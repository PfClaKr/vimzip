" vimzip: a portable, VSCode-like vim. Sections: basics, theme, code, git, timeline, search,
" tree, status bar, windows, panels, terminals, projects, git marks, keys, debugger.
set nocompatible
let &packpath = $VIMZIP . ',' . $VIMRUNTIME
let &runtimepath = $VIMZIP . ',' . $VIMRUNTIME . ',' . $VIMRUNTIME . '/after'
let s:cache = expand('~/.cache/vimzip')
for s:d in ['undo', 'sessions', 'tags', 'systags', 'words', 'backup']
  silent! call mkdir(s:cache . '/' . s:d, 'p')
endfor
" a cache file named after a path ('/' as '%'), or after a hash of it when that name would be too
" long for a file name (255 bytes, reached sooner with Korean; room left for a '.tmp')
function! s:CacheName(path, ext) abort
  let name = substitute(a:path, '[/\\:]', '%', 'g') . a:ext
  return strlen(name) <= 240 ? name : sha256(a:path) . a:ext
endfunction
" the folder a session file is for: from its name, or (a hashed name) its cd line
function! s:SessionDir(file) abort
  let name = fnamemodify(a:file, ':t:r')
  if name =~# '%'
    return substitute(name, '%', '/', 'g')
  endif
  let cd = matchstr(join(filter(readfile(a:file, '', 40), 'v:val =~# "^cd "')[: 0]), '^cd \zs.*')
  return substitute(cd, '\\\(.\)', '\1', 'g')
endfunction

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

" ─── basics ──────────────────────────────────────────────────────────────────────────────────────
" basics
set encoding=utf-8 fileencodings=ucs-bom,utf-8,cp949,latin1
set autoindent smarttab tabstop=4 shiftwidth=4
set number cursorline signcolumn=yes scrolloff=5 showmatch
set hidden autoread mouse=a belloff=all splitright splitbelow
set laststatus=2 showtabline=2 noshowmode showcmd noruler
" long lines wrap at word boundaries, continued under their own indent
set linebreak breakindent breakindentopt=shift:4
" except in minified or generated files (a 6 MB line of JSON): word wrap and the bracket match
" walk the whole line on every redraw, seconds per key
function! s:LongLines() abort
  if &buftype ==# '' && !empty(filter(range(1, min([line('$'), 100])), 'col([v:val, "$"]) > 3000'))
    setlocal nolinebreak nobreakindent
    let [b:matchparen_timeout, b:matchparen_insert_timeout] = [20, 20]
  endif
endfunction
augroup vimzip_long
  autocmd!
  autocmd BufWinEnter * call s:LongLines()
augroup END
set fillchars+=vert:│
" windows side by side: scrolling one line redrew the whole window (5x the output, a lagging
" terminal while a key is held). The vim script asks whether the terminal has left/right margins.
if get(g:, 'vimzip_decslrm', 0)
  let &t_CV = "\e[%i%p1%d;%p2%ds"
  let &t_ti .= "\e[?69h"
  let &t_te = "\e[?69l" . &t_te
endif
" opening or closing a window leaves the others as they are (vim would make them all equal)
set noequalalways
set incsearch hlsearch ignorecase smartcase
" exact-case tag lookups can binary-search the sorted tags file (gd 540 ms -> 1 ms on LLVM)
set tagcase=match
set backspace=indent,eol,start wildmenu wildoptions=pum display=lastline
set ttimeout ttimeoutlen=50 updatetime=300
set completeopt=menuone,popup noautocomplete
set undofile
" vim names an undo file after the whole path: for one longer than a file name may be, every save
" failed to write it (E828) and the history was lost. Those keep it under a hash of the path.
function! s:LongUndo(event) abort
  let f = expand('<afile>:p')
  if &buftype !=# '' || f ==# '' || strlen(f) <= 250
    return
  endif
  setlocal noundofile
  let u = s:cache . '/undo/' . sha256(f)
  if a:event ==# 'read' && filereadable(u)
    silent! execute 'rundo' fnameescape(u)
  elseif a:event ==# 'write'
    silent! execute 'wundo!' fnameescape(u)
  endif
endfunction
augroup vimzip_undo
  autocmd!
  autocmd BufReadPost * call s:LongUndo('read')
  autocmd BufWritePre * call s:LongUndo('before')
  autocmd BufWritePost * call s:LongUndo('write')
augroup END
let &undodir = s:cache . '/undo'
" no swap files: changes are saved within a second anyway, and a swap file only gets in the way
" (the E325 prompt) when a project is open in two vims
set noswapfile
" a save writes the file in place, its safety copy in the cache: the project folder itself does not
" change, so the tree is not reread and its git colors not recomputed after every save (1 s each
" with 10000 changed files), and file watchers see one change, not a new file
set backupcopy=yes
let &backupdir = s:cache . '/backup//'

" autosave on leaving insert mode, after normal-mode changes, and on focus/buffer change
" saving a new file creates its folders, like VSCode
augroup vimzip_mkdir
  autocmd!
  autocmd BufWritePre * if &buftype ==# '' && expand('<afile>') !~# '^\a\+://' && !isdirectory(expand('<afile>:p:h'))
        \ | call mkdir(expand('<afile>:p:h'), 'p') | endif
augroup END
function! s:AutoSave() abort
  if &modified && &buftype ==# '' && &modifiable && !&readonly && expand('%') !=# ''
        \ && &filetype !~# '^\(gitcommit\|gitrebase\)$'
    " a failed save says so (no permission, disk full, an encoding that cannot be written):
    " silently the file stayed as it was while the tab looked saved
    try
      " changed on disk meanwhile (another vim, git, a formatter): first vim's usual question, keep
      " this version (OK, then "really write?" confirms) or load the file's (Load); the bare
      " "really write? (y/n)" alone offered no way to get the file's version
      checktime %
      silent update
    catch
      echohl ErrorMsg
      echomsg (&modified ? 'Not saved: ' : 'Saved, but: ') . substitute(v:exception, '^Vim(\a\+):', '', '')
      echohl None
    endtry
  endif
endfunction
" the batched save waits while a prompt or the command line is up (:cdo ends at "Press ENTER", and
" the last file it changed stayed unsaved); typing saves on leaving insert mode instead
function! s:SaveLater(...) abort
  if mode() ==# 'n'
    call s:AutoSave()
  elseif mode() !~# '^[iR]'
    let s:save_timer = timer_start(500, function('s:SaveLater'))
  endif
endfunction
augroup vimzip_autosave
  autocmd!
  " ++nested: the write must fire BufWritePost, or linting, git signs and tags never see the save
  autocmd InsertLeave,FocusLost,BufLeave * ++nested call s:AutoSave()
  " batch quick normal-mode edits (x, dd, ...) into one save, so linters and ctags run once
  autocmd TextChanged * call timer_stop(get(s:, 'save_timer', -1))
        \ | let s:save_timer = timer_start(1000, function('s:SaveLater'))
  autocmd FocusGained,BufEnter,CursorHold * silent! checktime
augroup END

" ─── resources ─────────────────────────────────────────────────────────────────────────────────
" The CPUs and memory this vim may use: the CPUs it may run on, capped by a container's cgroup
" quota, and the free memory, capped by a cgroup limit (cgroup v2 or v1). Under 2 CPUs or 1 GB free
" vimzip runs light (see s:Light at the end); g:vimzip_lite = 1 / 0 or $VIMZIP_LITE forces it.
function! s:FirstLine(file) abort
  return filereadable(a:file) ? get(readfile(a:file, '', 1), 0, '') : ''
endfunction
function! s:Resources(cg) abort
  let cpus = 0
  for part in split(matchstr(join(filter(readfile('/proc/self/status'), 'v:val =~# "^Cpus_allowed_list"')), ':\s*\zs\S*'), ',')
    let [a, b] = (split(part, '-') + [part])[0 : 1]
    let cpus += str2nr(b) - str2nr(a) + 1
  endfor
  let cpus = cpus ? cpus * 1.0 : 1.0
  let quota = split(s:FirstLine(a:cg . '/cpu.max'))
  if len(quota) == 2 && quota[0] =~# '^\d\+$'
    let cpus = min([cpus, str2float(quota[0]) / str2float(quota[1])])
  elseif str2nr(s:FirstLine(a:cg . '/cpu/cpu.cfs_quota_us')) > 0
    let cpus = min([cpus, str2float(s:FirstLine(a:cg . '/cpu/cpu.cfs_quota_us'))
          \ / str2float(s:FirstLine(a:cg . '/cpu/cpu.cfs_period_us'))])
  endif
  let mem = str2nr(matchstr(join(filter(readfile('/proc/meminfo'), 'v:val =~# "^MemAvailable"')), '\d\+')) / 1024
  let mem = mem > 0 ? mem : 1000000
  for [limit, used] in [['/memory.max', '/memory.current'], ['/memory/memory.limit_in_bytes', '/memory/memory.usage_in_bytes']]
    let l = s:FirstLine(a:cg . limit)
    if l =~# '^\d\+$' && str2float(l) < 1.0e15  " a real limit, not 'max' or the v1 'no limit' number
      let mem = min([mem, float2nr((str2float(l) - str2float(s:FirstLine(a:cg . used))) / 1048576.0)])
      break
    endif
  endfor
  return {'cpus': cpus, 'mem': mem}
endfunction
let s:res = s:Resources('/sys/fs/cgroup')
" threads for rg: the CPUs vim may use, not every core of the host
let s:jobs = max([1, float2nr(ceil(s:res.cpus))])
let $VIMZIP_JOBS = s:jobs

" ─── theme ───────────────────────────────────────────────────────────────────────────────────────
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
  " status bar: built-in gray, or a theme file (themes/*.vim) picked by g:vimzip_theme
  highlight VimzipBar ctermfg=252 ctermbg=238 guifg=#d0d0d0 guibg=#444444 cterm=NONE gui=NONE
  highlight VimzipModeNormal ctermfg=235 ctermbg=250 guifg=#1c1c1c guibg=#bcbcbc cterm=bold gui=bold
  highlight VimzipModeInsert ctermfg=235 ctermbg=110 guifg=#1c1c1c guibg=#87afd7 cterm=bold gui=bold
  highlight VimzipModeVisual ctermfg=235 ctermbg=179 guifg=#1c1c1c guibg=#d7af5f cterm=bold gui=bold
  highlight VimzipModeReplace ctermfg=235 ctermbg=167 guifg=#1c1c1c guibg=#d75f5f cterm=bold gui=bold
  let f = filter(VimzipThemes(), 'fnamemodify(v:val, ":t:r") ==# get(g:, "vimzip_theme", "gray")')
  if !empty(f)
    execute 'source' fnameescape(f[0])
  endif
  highlight VimzipTitle ctermfg=250 ctermbg=235 guifg=#bbbbbb guibg=#252526 cterm=NONE gui=NONE
  " vim fills the cell where two bottom status lines meet with StatusLine(NC): the bar's colors
  " (the two must still differ, or vim draws ^ and = there; nocombine changes nothing visible)
  let id = hlID('VimzipBar')
  let c = map(['fg', 'bg'], 'synIDattr(id, v:val, "cterm")')
  let g = map(['fg#', 'bg#'], 'synIDattr(id, v:val, "gui")')
  let colors = printf('ctermfg=%s ctermbg=%s guifg=%s guibg=%s', c[0], c[1], g[0], g[1])
  let colors = substitute(colors, '=\ze\( \|$\)', '=NONE', 'g')
  execute 'highlight StatusLine' colors 'cterm=NONE gui=NONE'
  execute 'highlight StatusLineNC' colors 'cterm=nocombine gui=nocombine'
  for g in ['StatusLineTerm', 'StatusLineTermNC']
    execute 'highlight' g 'ctermfg=250 ctermbg=235 guifg=#bbbbbb guibg=#252526 cterm=NONE gui=NONE'
  endfor
  " thin window borders
  highlight VertSplit ctermfg=238 ctermbg=NONE guifg=#3a3a3a guibg=NONE cterm=NONE gui=NONE
  highlight VertSplitNC ctermfg=238 ctermbg=NONE guifg=#3a3a3a guibg=NONE cterm=NONE gui=NONE
  " git change marks at the right edge of each window
  highlight VimzipRuler ctermbg=NONE guibg=NONE
  highlight VimzipRulerAdd ctermfg=71 ctermbg=NONE guifg=#5faf5f guibg=NONE
  highlight VimzipRulerChange ctermfg=74 ctermbg=NONE guifg=#5fafd7 guibg=NONE
  highlight VimzipRulerDelete ctermfg=167 ctermbg=NONE guifg=#d75f5f guibg=NONE
endfunction
autocmd ColorScheme * call s:Highlights()
" theme files: ~/.config/vimzip/themes/*.vim first, then the bundled ones
function! VimzipThemes(...) abort
  let files = globpath(expand('~/.config/vimzip/themes') . ',' . $VIMZIP . '/themes', '*.vim', 0, 1)
  if !a:0
    return files
  endif
  let names = uniq(sort(map(files, 'fnamemodify(v:val, ":t:r")')))
  return a:0 == 3 ? filter(names, 'stridx(v:val, a:1) == 0') : names
endfunction
" :Theme lists themes, :Theme nord switches (keep it with let g:vimzip_theme in ~/.config/vimzip/vimrc)
function! s:Theme(name) abort
  if empty(a:name)
    echo join(VimzipThemes(1), '  ')
  elseif index(VimzipThemes(1), a:name) < 0
    echohl ErrorMsg | echo 'No theme: ' . a:name | echohl None
  else
    let g:vimzip_theme = a:name
    call s:Highlights()
    redrawstatus!
  endif
endfunction
command! -bar -nargs=? -complete=customlist,VimzipThemes Theme call s:Theme(<q-args>)
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

" ─── code: linting, go to definition, tags ───────────────────────────────────────────────────────
" ALE runs the language servers (see "language servers" below) and plain checkers
let g:ale_linters = {}
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_completion_enabled = 0
" Space ce / K: details in a popup at the cursor instead of a split
let g:ale_detail_to_floating_preview = 1
let g:ale_hover_to_floating_preview = 1
let g:ale_floating_window_border = ['│', '─', '╭', '╮', '╯', '╰', '│', '─']

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
  let f = s:cache . '/systags/' . s:CacheName(src, '.tags')
  call system('ctags --languages=C,C++ --langmap=C:+.h --kinds-C=+px --kinds-C++=+px -L - -f '
        \ . shellescape(f), join(hdrs, "\n"))
  if v:shell_error | return 0 | endif
  let tags = empty(&l:tags) ? &g:tags : &l:tags
  if index(split(tags, ','), f) < 0
    let &l:tags = tags . ',' . escape(f, ',')
  endif
  return 1
endfunction

" the file an #include names: next to this one, in the project's include folders, then where the
" compiler looks (its list asked once)
function! s:IncludeFile(name) abort
  let dirs = [expand('%:p:h'), expand('%:p:h:h') . '/include', getcwd(), getcwd() . '/include']
  let lang = &filetype ==# 'cpp' ? 'c++' : 'c'
  if !has_key(get(s:, 'sys_include', {}), lang)
    let s:sys_include = get(s:, 'sys_include', {})
    let cc = get(filter(lang ==# 'c++' ? ['c++', 'g++', 'clang++'] : ['cc', 'gcc', 'clang'], 'executable(v:val)'), 0, '')
    let s:sys_include[lang] = cc ==# '' ? [] : map(filter(systemlist(cc . ' -E -Wp,-v -x ' . lang . ' /dev/null'),
          \ 'v:val =~# "^ /"'), 'trim(v:val)')
  endif
  for d in dirs + s:sys_include[lang]
    if filereadable(d . '/' . a:name)
      return simplify(d . '/' . a:name)
    endif
  endfor
  return ''
endfunction

" go to definition: the language server, else project tags, else (C/C++) included system headers;
" on an #include line, that file
function! s:GoDef() abort
  let c = &filetype =~# '^\(c\|cpp\)$'
  if s:LspHere()
    ALEGoToDefinition
    return
  endif
  let inc = c ? matchstr(getline('.'), '^\s*#\s*include\s*[<"]\zs[^>"]\+') : ''
  if inc !=# ''
    let f = s:IncludeFile(inc)
    if f !=# ''
      execute 'edit' fnameescape(f)
      return
    endif
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

" ─── language servers ────────────────────────────────────────────────────────────────────────────
" Per language: id (for :Lsp and g:vimzip_lsp), name, filetypes, and the servers to try in order as
" [ALE linter, program, how to install]. One is on when installed (not under 1 GB free: s:Light);
" :Lsp lists them and turns one on or off, kept in ~/.config/vimzip/lsp.json.
let s:servers = [
  \ ['c', 'C/C++', ['c', 'cpp'], [['clangd', 'clangd', 'install clangd (apt, brew, ...)']]],
  \ ['rust', 'Rust', ['rust'], [['analyzer', 'rust-analyzer', 'rustup component add rust-analyzer']]],
  \ ['python', 'Python', ['python'], [['pyright', 'pyright-langserver', 'npm install -g pyright'],
  \                                  ['pylsp', 'pylsp', 'pip install python-lsp-server']]],
  \ ['go', 'Go', ['go'], [['gopls', 'gopls', 'go install golang.org/x/tools/gopls@latest']]],
  \ ['dart', 'Dart/Flutter', ['dart'], [['analysis_server', 'dart', 'install the Dart or Flutter SDK']]],
  \ ['typescript', 'TypeScript/JS', ['typescript', 'javascript', 'typescriptreact', 'javascriptreact'],
  \   [['tsserver', 'tsserver', 'npm install -g typescript']]],
  \ ['lua', 'Lua', ['lua'], [['lua_language_server', 'lua-language-server', 'install lua-language-server']]],
  \ ['bash', 'Bash', ['sh'], [['language_server', 'bash-language-server', 'npm install -g bash-language-server']]],
  \ ['zig', 'Zig', ['zig'], [['zls', 'zls', 'install zls']]]]
" plain checkers in place of a server that is off, or next to one (s:also); ALE skips missing ones
let s:checkers = {'c': ['cc'], 'cpp': ['cc'], 'sh': ['shellcheck'], 'python': ['ruff', 'flake8'],
  \ 'go': ['gofmt', 'govet'], 'lua': ['luacheck'], 'typescript': ['eslint'], 'javascript': ['eslint']}
let s:also = {'python': ['ruff'], 'typescript': ['eslint'], 'javascript': ['eslint']}
let s:lsp_file = expand('~/.config/vimzip/lsp.json')
let s:lsp_on = {}  " filetype: the ALE linter of its server, while on
function! s:LspSaved() abort
  try
    let d = json_decode(join(readfile(s:lsp_file), ''))
    return type(d) == v:t_dict ? d : {}
  catch
    return {}
  endtry
endfunction
" on PATH, and not one of rustup's stand-ins for a component it has not installed (rust-analyzer)
function! s:Installed(prog) abort
  let p = exepath(a:prog)
  let rustup = fnamemodify(p, ':h') . '/rustup'
  if p !=# '' && (resolve(p) =~# '/rustup$' || (executable(rustup) && getfsize(p) == getfsize(rustup)))
    let home = $RUSTUP_HOME !=# '' ? $RUSTUP_HOME : expand('~/.rustup')
    return !empty(glob(home . '/toolchains/*/bin/' . a:prog, 1, 1))
  endif
  return p !=# ''
endfunction
" [on/off/missing, program (or how to install), ALE linter]; :Lsp choices win over g:vimzip_lsp
function! s:LspState(lang) abort
  let want = get(extend(copy(get(g:, 'vimzip_lsp', {})), s:LspSaved()), a:lang[0], -1)
  let servers = copy(a:lang[3])
  if type(want) == v:t_string  " a server by name: let g:vimzip_lsp = {'python': 'pylsp'}
    call filter(servers, 'v:val[0] ==# want')
    let want = 1
  endif
  let found = filter(copy(servers), 's:Installed(v:val[1])')
  if empty(found)
    return ['missing', get(servers, 0, a:lang[3][0])[2], '']
  endif
  let on = want is -1 ? !(s:lite && s:res.mem < 1024) : !!want
  return [on ? 'on' : 'off', found[0][1], found[0][0]]
endfunction
function! s:LspSetup() abort
  let s:lsp_on = {}
  for lang in s:servers
    let [state, _, linter] = s:LspState(lang)
    for ft in lang[2]
      let g:ale_linters[ft] = state ==# 'on' ? [linter] + get(s:also, ft, []) : get(s:checkers, ft, [])
      if state ==# 'on'
        let s:lsp_on[ft] = linter
      endif
    endfor
  endfor
endfunction
function! s:LspHere() abort
  return has_key(s:lsp_on, &filetype)
endfunction
" the server's completion on Ctrl+x Ctrl+o
function! s:LspOmni(buf) abort
  if has_key(s:lsp_on, getbufvar(a:buf, '&filetype'))
    call setbufvar(a:buf, '&omnifunc', 'ale#completion#OmniFunc')
  elseif getbufvar(a:buf, '&omnifunc') ==# 'ale#completion#OmniFunc'
    call setbufvar(a:buf, '&omnifunc', '')
  endif
endfunction
augroup vimzip_lsp
  autocmd!
  autocmd FileType * call s:LspOmni(bufnr(''))
augroup END
" :Lsp {language} [on|off]: switch a server (no argument: the list); its open files are checked again
function! s:LspSet(id, ...) abort
  let lang = get(filter(copy(s:servers), 'v:val[0] ==# a:id'), 0, [])
  if empty(lang)
    echohl WarningMsg | echo 'Unknown language: ' . a:id . ' (' . join(map(copy(s:servers), 'v:val[0]'), ', ') . ')' | echohl None
    return
  endif
  if a:0 && a:1 !~? '^\(on\|off\|1\|0\)$'
    echohl WarningMsg | echo 'Lsp ' . a:id . ' on, or off (not ' . a:1 . ')' | echohl None
    return
  endif
  let [state, server, linter] = s:LspState(lang)
  " (one not installed yet can still be turned off ahead)
  if state ==# 'missing' && !(a:0 && a:1 =~? '^\(off\|0\)$')
    echohl WarningMsg | echo lang[1] . ': no language server installed. To get one: ' . server | echohl None
    return
  endif
  let on = a:0 ? a:1 =~? '^\(on\|1\)$' : state !=# 'on'
  let saved = s:LspSaved()
  let saved[a:id] = on ? 1 : 0
  call mkdir(fnamemodify(s:lsp_file, ':h'), 'p')
  call writefile([json_encode(saved)], s:lsp_file)
  call s:LspSetup()
  if !on && linter !=# ''
    execute 'silent! ALEStopLSP!' linter
  endif
  for b in getbufinfo({'bufloaded': 1})
    if index(lang[2], getbufvar(b.bufnr, '&filetype')) >= 0
      call s:LspOmni(b.bufnr)
      silent! call ale#Queue(0, 'lint_file', b.bufnr)
    endif
  endfor
  echo lang[1] . ': ' . (state ==# 'missing' ? 'stays off when a language server is installed' : server . (on ? ' on' : ' off'))
endfunction
function! s:LspMenu(...) abort
  let lines = []
  for lang in s:servers
    let [state, server, _] = s:LspState(lang)
    call add(lines, printf('%s %-14s %s', state ==# 'on' ? '●' : state ==# 'off' ? '○' : ' ', lang[1],
          \ state ==# 'on' ? server : state ==# 'off' ? server . ' (off)' : 'not installed: ' . server))
  endfor
  let id = popup_menu(lines, {'title': ' Language servers  Enter: on/off  Esc: close ', 'callback': function('s:LspPicked'),
        \ 'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1]})
  call win_execute(id, 'call cursor(' . get(a:, 1, 1) . ', 1)')
endfunction
function! s:LspPicked(id, result) abort
  if a:result > 0
    call s:LspSet(s:servers[a:result - 1][0])
    call s:LspMenu(a:result)
  endif
endfunction
function! VimzipLspComplete(lead, line, pos) abort
  let words = len(split(a:line[: a:pos - 1], ' ', 1)) <= 2 ? map(copy(s:servers), 'v:val[0]') : ['on', 'off']
  return filter(words, 'stridx(v:val, a:lead) == 0')
endfunction
command! -nargs=* -complete=customlist,VimzipLspComplete Lsp
      \ if <q-args> ==# '' | call s:LspMenu() | else | call s:LspSet(<f-args>) | endif

" gutentags: keep tag files out of projects
let g:gutentags_cache_dir = s:cache . '/tags'
" index only source files (huge projects also skip test dirs): LLVM 474 MB -> 140 MB of tags
let g:gutentags_file_list_command = 'vimzip-files'
" gutentags hands a saved file's path to a shell script inside quotes: a ' in the name broke the
" script (the project's tags stopped updating) and a $ named another file. Those files wait for the
" next full index (which reads the file list from a file).
function! VimzipTagsFor(path) abort
  return a:path !~# '[''"$`\\]'
endfunction
let g:gutentags_init_user_func = 'VimzipTagsFor'

" gitgutter: its first git calls block while vim starts, so turn it on after the first screen
let g:gitgutter_enabled = 0
" its :GitGutterEnable diffs every listed buffer, also a restored session's unloaded ones: they
" read as empty, so each diff is the whole file (30 big files froze vim for 4 s). Diff the visible
" ones; the rest are diffed when shown.
function! s:GitGutterOn() abort
  for b in getbufinfo({'buflisted': 1})
    call gitgutter#utility#setbufvar(b.bufnr, 'enabled', !has_key(b.variables, 'vimzip_view'))
  endfor
  let g:gitgutter_enabled = 1
  call gitgutter#all(1)
endfunction
" its keys are set with the other git keys (Space g, ]c [c)
let g:gitgutter_map_keys = 0
" Space gp: the hunk in a popup at the cursor
let g:gitgutter_preview_win_floating = 1

" ─── git ─────────────────────────────────────────────────────────────────────────────────────────
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
  if !g:vimzip_blame || &buftype !=# '' || &modified || exists('b:vimzip_view') || !filereadable(expand('%:p'))
        \ || empty(FugitiveGitDir())
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
  call prop_add(a:lnum, 0, {'type': 'vimzip_blame', 'bufnr': a:buf, 'text': text, 'text_align': 'after', 'text_padding_left': 4, 'text_wrap': 'truncate'})
  let s:blame_at = [a:buf, a:lnum]
endfunction
" commit of the current line in a popup (Space gc)
function! s:CommitPopup() abort
  " paths as they are, not quoted with octal escapes (Korean and other non-ASCII names)
  let git = 'git -c core.quotepath=false -C ' . shellescape(expand('%:p:h'))
  let out = systemlist(git . ' blame --porcelain -L ' . line('.') . ',' . line('.') . ' -- ' . shellescape(expand('%:t')))
  if v:shell_error || empty(out)
    " (a file added to git but never committed has no line in HEAD to blame)
    let out = ['0']
  endif
  let sha = matchstr(out[0], '^\x\+')
  let show = git . ' show --no-color --format=' . shellescape('%h  %an, %ar%n%n%B') . ' '
  if sha =~# '^0\+$'
    let lines = ['Uncommitted changes']
  else
    " --stat diffs every file: 12 s for a 190000-file import, so a big commit lists its first files
    let files = systemlist(git . ' show --no-color --format= --name-only ' . sha)
    let lines = len(files) <= 100 ? systemlist(show . '--stat ' . sha)
          \ : systemlist(show . '-s ' . sha) + map(files[:19], '" " . v:val') + [printf(' ... %d files changed', len(files))]
  endif
  call popup_atcursor(lines, {'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'padding': [0, 1, 0, 1], 'moved': 'any', 'maxheight': 20})
endfunction
" ─── timeline ────────────────────────────────────────────────────────────────────────────────────
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
function! s:TreeGone() abort
  if exists('g:NERDTree') && !g:NERDTree.IsOpen() && bufwinnr(s:tl.buf) > 0
    call s:ToggleTimeline()
    let s:timeline_hidden = 1
  endif
endfunction
function! s:TreeBack() abort
  if get(s:, 'timeline_hidden', 0) && exists('g:NERDTree') && g:NERDTree.IsOpen() && bufwinnr(s:tl.buf) < 0
    let s:timeline_hidden = 0
    call s:ToggleTimeline()
  endif
endfunction
function! s:ToggleTimeline() abort
  if bufwinnr(s:tl.buf) > 0
    if get(s:tl, 'viewing', 0)
      call s:TimelineCloseDiff()
    endif
    execute bufwinnr(s:tl.buf) . 'close'
    let s:timeline_hidden = 0
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
  execute 'resize' s:PanelSize('timeline')
  setlocal winfixheight
  let s:set[win_getid()] = winheight(0)
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
  " (no optional locks: a status refreshing the index right after a save made a git commit typed in
  " the terminal at that moment fail with index.lock)
  let cmd = 'cd ' . dir . ' && GIT_OPTIONAL_LOCKS=0 git status --porcelain -- ' . name . '; echo @@; git -c core.quotepath=false log --follow -n 300 --name-only'
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
  if get(s:tl, 'viewing', 0)
    call s:TimelineCloseDiff()  " one comparison at a time
  endif
  let w = bufwinid(s:tl.file)
  if w < 0
    wincmd p
    call s:EditWin()
    execute 'edit' fnameescape(s:tl.file)
    let w = win_getid()
  endif
  call win_gotoid(w)
  let s:tl.diffwin = w
  let s:tl.viewing = 1
  try
    if it.sha ==# ''
      call s:DiffSplit('', 'HEAD')
    else
      let path = it.path !=# '' ? it.path : expand('%')
      execute 'Gedit' fnameescape(it.sha . ':' . path)
      " the commit that added the file has nothing to compare with: show the file as it was
      call system('git -C ' . shellescape(fnamemodify(s:tl.file, ':h')) . ' cat-file -e ' . shellescape(it.sha . '~1:' . path))
      if !v:shell_error
        call s:DiffSplit('leftabove', it.sha . '~1')
      else
        setlocal nobuflisted
        nnoremap <buffer> <silent> q :call <SID>TimelineCloseDiff()<CR>
      endif
    endif
  catch
    echohl WarningMsg | echo 'Timeline: ' . v:exception | echohl None
  endtry
  " old on the left, new on the right, like VSCode; past versions stay out of the tab bar
  for d in filter(range(1, winnr('$')), 'getwinvar(v:val, "&diff") || win_getid(v:val) == s:tl.diffwin')
    call setwinvar(d, 'vimzip_tl', 1)
    call win_execute(win_getid(d), 'nnoremap <buffer> <silent> q :call <SID>TimelineCloseDiff()<CR>')
    if bufname(winbufnr(d)) =~# '^fugitive://'
      call setbufvar(winbufnr(d), '&buflisted', 0)
    endif
  endfor
  call lightline#update()
endfunction
" a:1: keep the current window as it is (the comparison was left by opening another file there)
function! s:TimelineCloseDiff(...) abort
  let s:tl.viewing = 0
  let keep = a:0 ? win_getid() : get(s:tl, 'diffwin', 0)
  diffoff!
  for w in reverse(range(1, winnr('$')))
    if win_getid(w) != keep && (bufname(winbufnr(w)) =~# '^fugitive://' || getwinvar(w, 'vimzip_tl', 0))
      execute w . 'close'
    endif
  endfor
  for w in range(1, winnr('$'))
    call setwinvar(w, 'vimzip_tl', 0)
  endfor
  if !a:0 && win_gotoid(get(s:tl, 'diffwin', 0))
    execute 'edit' fnameescape(s:tl.file)
  endif
  for b in getbufinfo()
    if getbufvar(b.bufnr, '&buftype') ==# '' || b.name =~# '^fugitive://'
      call win_execute(get(b.windows, 0, -1), 'silent! nunmap <buffer> q')
    endif
  endfor
  for b in getbufinfo()
    if b.name =~# '^fugitive://' && empty(b.windows)
      execute 'silent! bwipeout' b.bufnr
    endif
  endfor
endfunction
" only side panels left (the last editor window closed): show a file again, or leave vim after :q
function! s:QuitIfOnlyPanels() abort
  if getcmdwintype() !=# '' || mode() !=# 'n' && mode() !=# 't'
    return
  endif
  for w in range(1, winnr('$'))
    let b = winbufnr(w)
    if index(['nerdtree', 'tagbar', 'vimziptimeline'], getbufvar(b, '&filetype')) < 0
          \ && index(['terminal', 'quickfix'], getbufvar(b, '&buftype')) < 0 && b != s:tl.buf
      return
    endif
  endfor
  let unsaved = filter(getbufinfo({'bufmodified': 1}), 'getbufvar(v:val.bufnr, "&buftype") ==# ""')
  let files = sort(getbufinfo({'buflisted': 1}), {a, b -> b.lastused - a.lastused})
  if get(s:, 'quitting', 0) && empty(unsaved)
    qall  " :q in the last file
  endif
  let s:quitting = 0
  " only panels are left (the last editor window was closed): show a file again, the unsaved one
  " first, rather than leaving vim
  let tree = filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&filetype") ==# "nerdtree"')
  if !empty(tree)
    noautocmd call win_gotoid(win_getid(tree[0]))
    rightbelow vertical new
  else
    topleft vertical new
  endif
  let blank = bufnr('')
  if !empty(unsaved) || !empty(files)
    execute 'buffer' (empty(unsaved) ? files[0].bufnr : unsaved[0].bufnr)
    execute 'silent! bwipeout' blank
  endif
  call s:Layout()
  if !empty(unsaved)
    echohl ErrorMsg | echo 'No write since last change (:w name to save, :q! to discard)' | echohl None
  endif
endfunction

augroup vimzip_blame
  autocmd!
  autocmd BufEnter,BufWritePost * call s:TimelineUpdate()
  autocmd FileType vimziptimeline syntax match VimzipTimelineFile /\%1l.*/
        \ | syntax match VimzipTimelineAge /^\%>1l\S\+/ | syntax match VimzipTimelineDirty /^\*.*/
  autocmd CursorHold * call s:Blame()
  autocmd CursorMoved,CursorMovedI,InsertEnter,BufLeave * if exists('s:blame_at') | call s:BlameClear() | endif
augroup END

" ─── search ──────────────────────────────────────────────────────────────────────────────────────
" fzf
let $FZF_DEFAULT_COMMAND = 'rg -j ' . s:jobs . ' --files --hidden --glob "!.git"'

" project search: run rg only while there is a query (fzf.vim's :RG greps every line on an empty one)
function! s:Find(query, bang, ...) abort
  " a:1: match the text as typed (no regex)
  let rg = 'rg -j ' . s:jobs . ' --column --line-number --no-heading --color=always --smart-case --hidden --glob "!.git" '
  " a query that is no valid regex (foo( or a[i): found as typed, not an error and no results
  let reload = get(a:, 1, 0) ? '[ -z {q} ] || ' . rg . '-F -- {q} || :'
        \ : '[ -z {q} ] || { ' . rg . '-- {q} 2>/dev/null; [ $? -ne 2 ] || ' . rg . '-F -- {q}; } || :'
  call fzf#vim#grep(':', fzf#vim#with_preview({'options': ['--disabled', '--query', a:query,
    \ '--prompt', 'Find> ', '--bind', 'start:reload:' . reload, '--bind', 'change:reload:' . reload]}), a:bang)
endfunction
command! -bang -nargs=* Find call s:Find(<q-args>, <bang>0)
" search for the selection / the word under the cursor, as plain text
function! s:FindText(text) abort
  let text = get(split(a:text, "\n"), 0, '')
  call s:EditWin()
  if text =~# "\t"
    " fzf turns a tab in the query into a space: the tab goes as a regex \t instead
    call s:Find(substitute(escape(text, '\.^$|?*+()[]{}'), "\t", '\\t', 'g'), 0)
  else
    call s:Find(text, 0, 1)
  endif
endfunction

" ─── file tree ───────────────────────────────────────────────────────────────────────────────────
" nerdtree
let g:NERDTreeHijackNetrw = 0
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeIgnore = ['^\.git$']
let g:NERDTreeWinSize = 30
" a file renamed, moved or deleted in the tree (m) takes its open tab along, like VSCode, with no
" (yN) question whose key could be lost to a background event, leaving a tab on a file that is gone
let g:NERDTreeAutoDeleteBuffer = 1
" the tree's git colors: not recomputed whenever the cursor rests (a git status of the whole project
" every 0.3 s, 0.5 s of vim each time with 10000 changed files); after a save, and when the folders
" or git's index or HEAD change (a commit in the terminal, see s:TreeSyncHere)
let g:NERDTreeGitStatusUpdateOnCursorHold = 0
" a failed background status (any line on git's stderr) is not an error message in the middle of
" typing: the colors are redone at the next save, or within 30 s
let g:NERDTreeGitStatusLogLevel = 4
" and its parsing of `git status`, three function calls a line (0.5 s for 10000 changed files),
" done again in one loop once its file is loaded: the same result, several times faster
let s:git_keys = {'DD': 'Unmerged', 'AU': 'Unmerged', 'UD': 'Unmerged', 'UA': 'Unmerged',
      \ 'DU': 'Unmerged', 'AA': 'Unmerged', 'UU': 'Unmerged', '??': 'Untracked', '!!': 'Ignored'}
function! s:GitKey(x, y) abort
  let xy = a:x . a:y
  if !has_key(s:git_keys, xy)
    let s:git_keys[xy] = a:y ==# 'M' ? 'Modified' : a:y ==# 'D' ? 'Deleted' : a:y =~# '[RC]' ? 'Renamed'
          \ : a:x ==# 'D' ? 'Deleted' : a:x =~# '[MA]' ? 'Staged' : a:x =~# '[RC]' ? 'Renamed' : 'Unknown'
  endif
  return s:git_keys[xy]
endfunction
" (a compiled :def function: the same loop in legacy script took 0.3 s for 10000 lines)
def VimzipGitStatusLines(root: string, lines: list<string>, opts: dict<any>): dict<string>
  var result: dict<string> = {}
  # (the plugin passes g:, where these can be strings such as '2')
  var v2 = str2nr(get(opts, 'NERDTreeGitStatusPorcelainVersion', 2) .. '') == 2
  var dirty_only = str2nr(get(opts, 'NERDTreeGitStatusDirDirtyOnly', 1) .. '') != 0
  var is_rename = false
  var key = ''
  var path = ''
  for line in lines
    if is_rename
      [path, key, is_rename] = [root .. '/' .. line, 'Dirty', false]
    else
      # the fields before the path are ASCII, so character and byte offsets agree there
      if !v2
        [key, path] = [s:GitKey(line[0], line[1]), strpart(line, 3)]
      elseif line[0] == '1'
        [key, path] = [s:GitKey(line[2], line[3]), strpart(line, 113)]
      elseif line[0] == '2'
        path = strpart(line, 113)
        [key, path] = ['Renamed', strpart(path, stridx(path, ' ') + 1)]
      elseif line[0] == 'u'
        [key, path] = ['Unmerged', strpart(line, 161)]
      elseif line[0] == '?'
        [key, path] = ['Untracked', strpart(line, 2)]
      elseif line[0] == '!'
        [key, path] = ['Ignored', strpart(line, 2)]
      else
        throw '[nerdtree_git_status] unknown status: ' .. line
      endif
      path = root .. '/' .. path
      if path =~ '/$'
        path = strpart(path, 0, strlen(path) - 1)
      endif
      is_rename = key == 'Renamed'
      result[path] = key
    endif
    # the folders above it: Dirty, or (dirty_only off) their files' state while they agree
    if get(result, path, '') == 'Ignored'
      continue
    endif
    var dir = strpart(path, 0, strridx(path, '/'))
    while dir != root && strlen(dir) > strlen(root)
      var have = get(result, dir, '')
      if have == ''
        result[dir] = dirty_only ? 'Dirty' : key
      elseif dirty_only || have == 'Dirty' || have == key
        break
      else
        result[dir] = 'Dirty'
      endif
      dir = strpart(dir, 0, strridx(dir, '/'))
    endwhile
  endfor
  return result
enddef
function! s:FastGitStatus() abort
  function! gitstatus#util#ParseGitStatusLines(root, statusLines, opts) abort
    return VimzipGitStatusLines(a:root, a:statusLines, a:opts)
  endfunction
endfunction
augroup vimzip_gitstatus
  autocmd!
  " (its file is usually loaded while this vimrc runs, before these lines)
  autocmd VimEnter * if exists('*gitstatus#util#ParseGitStatusLines') | call s:FastGitStatus() | endif
  autocmd SourcePost */autoload/gitstatus/util.vim call s:FastGitStatus()
augroup END
let g:NERDTreeStatusline = -1
let g:tagbar_no_status_line = 1
let g:tagbar_compact = 2
" at most 1000 symbols: thousands took seconds each (see vimzip-ctags); none for files over 3 MB,
" which ctags alone takes seconds to read
let g:tagbar_ctags_bin = $VIMZIP . '/bin/vimzip-ctags'
let g:tagbar_file_size_limit = 3000000
" fzf preview beside the list, or above it when it would be under 40 columns wide (a narrow screen)
let g:fzf_preview_window = ['right,50%,<40(up,50%)', 'ctrl-/']
" a taller popup than fzf.vim's 60%, so the preview shows more of the file
let g:fzf_layout = {'window': {'width': 0.9, 'height': 0.8}}
" scrolling the preview (the file on the right) like vim: Ctrl+d / Ctrl+u half a page, Ctrl+f / Ctrl+b
" a page, Shift+Up / Down a line (the mouse wheel over it works too)
let $FZF_DEFAULT_OPTS = trim($FZF_DEFAULT_OPTS . ' --bind=ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up'
      \ . ',ctrl-f:preview-page-down,ctrl-b:preview-page-up,shift-down:preview-down,shift-up:preview-up')
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

" ─── tab bar and status bar ──────────────────────────────────────────────────────────────────────
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
" clicking a tab opens that file: Vim's tabline has no click handlers for buffers (only Neovim),
" so read the name under the mouse and find its buffer (names shown as 's/util.c' when duplicated)
function! s:Click() abort
  let s:user_resize = reltime()  " a press may start dragging a window edge
  let m = getmousepos()
  " a click on the git marks at a window's right edge: to that change, or, between marks, to that
  " part of the file (like clicking a scrollbar)
  let ruler = get(get(s:, 'ruler_info', {}), m.winid, {})
  if !empty(ruler)
    let r = m.winrow - 1
    let lnum = get(ruler.target, r, r * ruler.n / ruler.h + 1)
    return ":\<C-u>call win_gotoid(" . ruler.win . ")|call cursor(" . lnum . ", 1)|normal! ^zz\<CR>"
  endif
  if m.screenrow != 1 || m.winid
    return "\<LeftMouse>"
  endif
  " the row as text, with the screen column each character starts at (wide characters take two)
  let [row, cols] = ['', []]
  for c in range(1, &columns)
    let ch = screenstring(1, c)
    if ch !=# ''
      let row .= ch
      call add(cols, c)
    endif
  endfor
  for b in getbufinfo({'buflisted': 1})
    " the label is the file name, or with part of its path when two tabs share a name (s/util.c)
    let parts = split(fnamemodify(b.name, ':.'), '/')
    for n in range(len(parts), 1, -1)
      let label = n == 1 ? parts[-1] : pathshorten(join(parts[-n :], '/'))
      let at = stridx(row, ' ' . label . ' ')
      if at >= 0
        let first = cols[strchars(row[: at]) - 1]
        let last = cols[min([strchars(row[: at + strlen(label)]), len(cols)]) - 1]
        if m.screencol >= first && m.screencol <= last
          return ":\<C-u>call " . expand('<SID>') . "Buf('buffer " . b.bufnr . "')\<CR>"
        endif
        break
      endif
    endfor
  endfor
  return ''
endfunction
nnoremap <silent> <expr> <LeftMouse> <SID>Click()
function! s:InsertClick() abort
  return has_key(get(s:, 'ruler_info', {}), getmousepos().winid) ? "\<Esc>" . s:Click() : "\<LeftMouse>"
endfunction
inoremap <silent> <expr> <LeftMouse> <SID>InsertClick()
let g:NERDTreeMouseMode = 3

" One status bar for the whole screen (vim has no laststatus=3 as Neovim does).
" The status lines along the bottom edge together draw the bar for the current window: its
" left part in the leftmost one, its right part in the rightmost, plain bar in between.
" A window with another window below it gets a thin title row naming that lower window, like
" VSCode's panel headers (TIMELINE, TERMINAL, ...).
set laststatus=2 statusline=%!VimzipStatus()
" the bar may sit in another window's status line, so redraw them all as the cursor or mode changes
augroup vimzip_status
  autocmd!
  autocmd CursorMoved,CursorMovedI,ModeChanged,WinEnter,BufEnter,TextChanged,TextChangedI * call s:BarRefresh()
  autocmd WinResized,VimResized * call s:BarRefresh()
  " ++nested: the tree stepping aside (or back) takes the timeline under it along
  autocmd VimResized * ++nested call s:Layout()
  autocmd WinResized * call s:Resized()
augroup END
let s:modes = {'n': ['NORMAL', 'Normal'], 'i': ['INSERT', 'Insert'], 'R': ['REPLACE', 'Replace'],
  \ 'v': ['VISUAL', 'Visual'], 'V': ['V-LINE', 'Visual'], "\<C-v>": ['V-BLOCK', 'Visual'],
  \ 's': ['SELECT', 'Visual'], 'S': ['S-LINE', 'Visual'], 'c': ['COMMAND', 'Normal'], 't': ['TERMINAL', 'Insert']}
let s:languages = {'c': 'C', 'cpp': 'C++', 'python': 'Python', 'sh': 'Shell Script', 'bash': 'Shell Script',
  \ 'zsh': 'Shell Script', 'make': 'Makefile', 'cmake': 'CMake', 'markdown': 'Markdown', 'vim': 'Vim Script',
  \ 'json': 'JSON', 'yaml': 'YAML', 'javascript': 'JavaScript', 'typescript': 'TypeScript', 'go': 'Go',
  \ 'rust': 'Rust', 'java': 'Java', 'lua': 'Lua', 'html': 'HTML', 'css': 'CSS', 'xml': 'XML', 'sql': 'SQL',
  \ 'dockerfile': 'Dockerfile', 'gitcommit': 'Git Commit', 'gitignore': 'Ignore', 'text': 'Plain Text',
  \ 'vimzipimage': 'Image', 'vimzippdf': 'PDF'}
function! VimzipProblems(...) abort
  let b = a:0 ? a:1 : bufnr('')
  if getbufvar(b, '&buftype') !=# '' || !exists('g:loaded_ale') | return '' | endif
  let c = ale#statusline#Count(b)
  let e = c.error + c.style_error
  return printf('E %d  W %d', e, c.total - e)
endfunction
function! s:Title(w) abort
  let b = winbufnr(a:w)
  let ft = getbufvar(b, '&filetype')
  return ft ==# 'nerdtree' ? 'EXPLORER' : ft ==# 'vimziptimeline' ? 'TIMELINE' : ft ==# 'tagbar' ? 'OUTLINE'
        \ : getbufvar(b, '&buftype') ==# 'terminal' ? 'TERMINAL'
        \ : getbufvar(b, '&buftype') ==# 'quickfix' ? (get(getwininfo(a:w)[0], 'loclist') ? 'LOCATION LIST' : 'QUICKFIX')
        \ : getbufvar(b, '&buftype') ==# 'help' ? 'HELP' : ft ==# 'man' ? 'MANUAL'
        \ : (bufname(b) !=# '' ? fnamemodify(bufname(b), ':t') : '[No Name]') . (getbufvar(b, '&modified') ? ' +' : '')
endfunction
function! s:Esc(text) abort
  return substitute(a:text, '%', '%%', 'g')
endfunction
" the editor the bar describes: the current window, or the last file window when a panel has focus
" (a %! expression runs in the current window's context, so read everything through this id)
function! s:EditorWin() abort
  if &buftype ==# ''
    let s:editor = win_getid()
  endif
  let e = get(s:, 'editor', 0)
  if win_id2win(e) && getbufvar(winbufnr(e), '&buftype') ==# ''
    return e
  endif
  let files = filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&buftype") ==# ""')
  return empty(files) ? 0 : win_getid(files[0])
endfunction
" the window's status line is on the screen's last row (a winbar, like the debugger's, adds a row)
" (no window under it; not getwininfo(), which lays out the window's lines: 11 ms each in a long one)
function! s:AtBottom(w) abort
  let [row, col] = win_screenpos(a:w)
  let right = col + winwidth(a:w)
  for n in range(1, winnr('$'))
    let [r, c] = win_screenpos(n)
    if r > row && c < right && c + winwidth(n) > col
      return 0
    endif
  endfor
  return 1
endfunction
" the window that starts right under this one's status line, in the same column
function! s:Below(w) abort
  let [row, col] = win_screenpos(a:w)
  let [below, top] = [0, &lines]
  for n in range(1, winnr('$'))
    let [r, c] = win_screenpos(n)
    if c == col && r > row && r < top
      let [below, top] = [win_getid(n), r]
    endif
  endfor
  return below
endfunction
function! VimzipStatus() abort
  let w = g:statusline_winid
  let [row, col] = win_screenpos(w)
  if !s:AtBottom(w)
    " a title row is the header of the window below it, like VSCode's panel headers on top
    let below = s:Below(w)
    return '%#VimzipTitle# ' . (below ? s:Esc(s:Title(below)) : '')
  endif
  " this window's columns of the bar
  let [first, last] = [col, col + winwidth(w) - 1]
  let out = '%#VimzipBar#'
  let pos = first
  for [x, cells, group] in s:BarLayout()
    let [start, stop] = [max([x, first]), min([x + len(cells) - 1, last])]
    if start <= stop
      let part = cells[start - x : stop - x]
      " half of a wide character cut off by the window's edge
      if part[0] ==# '' | let part[0] = ' ' | endif
      if get(cells, stop - x + 1, 'x') ==# '' | let part[-1] = ' ' | endif
      let out .= repeat(' ', start - pos) . '%#' . group . '#' . s:Esc(join(part, '')) . '%#VimzipBar#'
      let pos = stop + 1
    endif
  endfor
  " pad to the window's edge ourselves: vim would fill with 'fillchars' (set to a bar letter, see s:BarJoins)
  return out . repeat(' ', last - pos + 1)
endfunction

" the bar laid out for the whole screen width: [[column, text, group], ...]
" Items are lists of screen cells (a wide character such as Hangul is the character and an empty
" second cell), so each window can cut out exactly its columns.
function! s:BarCells(x, text, joins) abort
  if a:text !~# '[^ -~]'
    return split(a:text, '\zs')  " plain ASCII: one cell per character
  endif
  let cells = []
  for ch in split(a:text, '\zs')
    if strwidth(ch) == 2
      " the cell where two status lines meet holds one narrow character: move a wide one past it
      while index(a:joins, a:x + len(cells)) >= 0 || index(a:joins, a:x + len(cells) + 1) >= 0
        call add(cells, ' ')
      endwhile
      call extend(cells, [ch, ''])
    else
      call add(cells, strwidth(ch) == 1 ? ch : '?')
    endif
  endfor
  return cells
endfunction
function! s:BarLayout() abort
  if exists('s:bar_now')
    return s:bar_now  " computed once per refresh for all the status lines (see s:BarRefresh)
  endif
  let joins = []
  for n in range(1, winnr('$'))
    let j = win_screenpos(n)[1] + winwidth(n)
    if j <= &columns && s:AtBottom(win_getid(n))
      call add(joins, j)
    endif
  endfor
  let e = s:EditorWin()
  let b = e ? winbufnr(e) : bufnr('')
  let [name, group] = get(s:modes, mode(), [toupper(mode()), 'Normal'])
  let placed = [[1, s:BarCells(1, ' ' . name . ' ', joins), 'VimzipMode' . group]]
  let x = len(placed[0][1]) + 3
  for item in [exists('*FugitiveHead') ? FugitiveHead(0, b) : '', VimzipProblems(b)]
    if item !=# ''
      call add(placed, [x, s:BarCells(x, item, joins), 'VimzipBar'])
      let x += len(placed[-1][1]) + 2
    endif
  endfor
  if !e
    return placed
  endif
  let [et, sw, ts] = [getbufvar(b, '&expandtab'), getbufvar(b, '&shiftwidth'), getbufvar(b, '&tabstop')]
  let [fenc, ff, ft] = [getbufvar(b, '&fileencoding'), getbufvar(b, '&fileformat'), getbufvar(b, '&filetype')]
  " virtcol() measures the line from its start: 90 ms per redraw deep in a 6 MB minified line
  let c = col('.', e)
  let items = [printf('Ln %d, Col %d', line('.', e), c > 2000 ? c : virtcol('.', 0, e)),
        \ et ? 'Spaces: ' . (sw ? sw : ts) : 'Tab Size: ' . ts,
        \ toupper(fenc !=# '' ? fenc : &encoding),
        \ get({'unix': 'LF', 'dos': 'CRLF', 'mac': 'CR'}, ff, ff),
        \ ft ==# '' ? 'Plain Text' : get(s:languages, ft, toupper(ft[0]) . ft[1:])]
  if !empty(getbufvar(b, 'vimzip_view'))
    let items[1 : 3] = ['', '', '']  " a picture or PDF: no indent, encoding or line endings
  endif
  " right-aligned with one space at the end; drop the least useful items first when short of room
  for drop in [0, 1, 2, 3, 4]
    if drop
      let items[drop] = ''
      if drop == 2 | let items[3] = '' | endif
    endif
    let right = join(filter(copy(items), 'v:val !=# ""'), '  ')
    let at = &columns - strwidth(right)
    if at > x
      return placed + [[at, s:BarCells(at, right, []), 'VimzipBar']]
    endif
  endfor
  return placed
endfunction

" vim draws the cell where two bottom status lines meet itself, with 'fillchars' stl/stlnc:
" set that window-locally to the bar's character there so the bar reads as one line
function! s:BarJoins() abort
  let layout = s:BarLayout()
  for n in range(1, winnr('$'))
    let [r, c] = win_screenpos(n)
    let j = c + winwidth(n)
    if !s:AtBottom(win_getid(n)) || j > &columns
      " not on the bottom edge (any more): back to the global value
      if getwinvar(n, 'vimzip_fcs', '') !=# ''
        call setwinvar(n, '&fillchars', '')
        call setwinvar(n, 'vimzip_fcs', '')
      endif
      continue
    endif
    let ch = ' '
    for [x, cells, _] in layout
      if j >= x && j < x + len(cells)
        let ch = cells[j - x]
      endif
    endfor
    let ch = ch =~# '^[,\\ ]\=$' || strwidth(ch) != 1 ? ' ' : ch
    let fcs = substitute(&g:fillchars, ',\=stl\(nc\)\=:[^,]*', '', 'g') . ',stl:' . ch . ',stlnc:' . ch
    if getwinvar(n, 'vimzip_fcs', '') !=# fcs
      call setwinvar(n, '&fillchars', fcs)
      call setwinvar(n, 'vimzip_fcs', fcs)
    endif
  endfor
endfunction
function! s:BarRefresh() abort
  unlet! s:bar_now
  let s:bar_now = s:BarLayout()
  call s:BarJoins()
  " mark every status line for the next screen update: :redrawstatus! updates the whole screen now,
  " once more per event (0.4 s each in a 6 MB minified line)
  let &g:statusline = &g:statusline
  unlet! s:bar_now
endfunction

" ─── windows, tabs and quitting ──────────────────────────────────────────────────────────────────
" switch/close buffers without touching the tree or terminal windows
function! s:EditWin() abort
  if &buftype !=# '' || exists('b:NERDTree')
    let e = s:EditorWin()
    if e
      call win_gotoid(e)
    else
      wincmd p
    endif
  endif
endfunction
" when a window closes (a terminal exits, a split is closed) and vim lands in a side panel,
" go back to the editor
function! s:AfterClose() abort
  if index(['nerdtree', 'tagbar', 'vimziptimeline'], &filetype) >= 0 && mode() ==# 'n'
    call s:EditWin()
  endif
  if get(s:, 'tree_hidden', 0)
    call s:Layout()
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
  if get(s:tl, 'viewing', 0) && (&diff || bufname('') =~# '^fugitive://')
    call s:TimelineCloseDiff()  " :q in a timeline comparison goes back to the file, like q
    return
  endif
  let editwins = len(filter(range(1, winnr('$')), 'getwinvar(v:val, "&buftype") ==# ""'))
  if &buftype ==# '' && &modified && !a:bang && editwins < 2
    " an unsaved buffer without a name (named ones are saved automatically): closing its only
    " window would leave vim with just the panels
    echohl ErrorMsg | echo 'No write since last change (:w name to save, :q! to discard)' | echohl None
    return
  endif
  if &buftype ==# '' && a:bang
    setlocal nomodified  " discard: keep autosave (on leaving the buffer) from writing it
  endif
  if &buftype !=# '' || editwins > 1 || len(getbufinfo({'buflisted': 1})) < 2
    let s:quitting = &buftype ==# '' && editwins < 2  " the last file: leave vim
    execute 'quit' . (a:bang ? '!' : '')
    return
  endif
  let b = bufnr('')
  bprevious
  execute 'bdelete' . (a:bang ? '!' : '') b
  redrawtabline
endfunction
command! -bang VimzipQuit call s:Quit(<bang>0)
command! -bang VimzipWriteQuit update | call s:Quit(<bang>0)
nnoremap <silent> <C-w>q :VimzipQuit<CR>
nnoremap <silent> <C-w><C-q> :VimzipQuit<CR>
nnoremap <silent> <C-w>c :VimzipQuit<CR>
nnoremap <silent> ZZ :VimzipWriteQuit<CR>
nnoremap <silent> ZQ :VimzipQuit!<CR>
cnoreabbrev <expr> q getcmdtype() ==# ':' && getcmdline() ==# 'q' ? 'VimzipQuit' : 'q'
cnoreabbrev <expr> wq getcmdtype() ==# ':' && getcmdline() ==# 'wq' ? 'VimzipWriteQuit' : 'wq'
cnoreabbrev <expr> x getcmdtype() ==# ':' && getcmdline() ==# 'x' ? 'VimzipWriteQuit' : 'x'

" ─── panels: terminal, AI agent, sizes ───────────────────────────────────────────────────────────
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
    execute 'resize' s:PanelSize('term')
  else
    execute 'botright terminal ++rows=' . s:PanelSize('term') . ' ++kill=hup ++close'
    call s:TermKeys()
    let s:term = bufnr('')
  endif
  setlocal winfixheight
  let s:set[win_getid()] = winheight(0)
  call s:Layout()  " the split took rows from the windows above (the timeline): give them back
endfunction

" AI agent on the right (Ctrl+Alt+I / Space a): g:vimzip_ai, $VIMZIP_AI, or the first agent CLI found
function! s:ToggleAi() abort
  let t = get(s:, 'ai', -1)
  let w = bufwinnr(t)
  if w > 0
    execute w . 'hide'
    call win_gotoid(get(s:, 'ai_from', 0))
    call s:Layout()
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
  call s:Layout('ai')
  let width = s:PanelWidths('ai').ai
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
  setlocal winfixwidth
  call s:Layout()
endfunction

" Panel sizes: the size you gave a panel (dragging its edge, Ctrl+w < >) is kept, otherwise a
" default that follows the screen. Side panels shrink on small screens so the editor keeps 40
" columns (on a very narrow one the tree steps aside until there is room again). Runs on resize,
" panel toggles and when windows open or close; Ctrl+w = goes back to the defaults.
let s:pref = {}
let s:set = {}
function! s:Kind(n) abort
  let b = winbufnr(a:n)
  let ft = getbufvar(b, '&filetype')
  return ft ==# 'nerdtree' ? 'tree' : ft ==# 'tagbar' ? 'tagbar' : ft ==# 'vimziptimeline' ? 'timeline'
        \ : b == get(s:, 'ai', -1) ? 'ai' : b == get(s:, 'term', -1) ? 'term' : ''
endfunction
function! s:PanelSize(kind) abort
  let default = {'tree': min([30, max([20, &columns / 4])]), 'tagbar': min([40, max([24, &columns * 3 / 10])]),
        \ 'ai': min([100, max([30, &columns * 2 / 5])]), 'term': max([6, (&lines - 4) * 3 / 10]),
        \ 'timeline': max([6, (&lines - &cmdheight - 3) * 2 / 5])}[a:kind]
  let most = a:kind ==# 'term' || a:kind ==# 'timeline' ? (&lines - 4) * 2 / 3
        \ : a:kind ==# 'ai' ? &columns * 3 / 5 : min([60, &columns / 3])
  return max([6, min([get(s:pref, a:kind, default), most])])
endfunction
" a panel whose size changed from what vim was told keeps that size from now on
function! s:Resized() abort
  " a window opened or closed (vim gave its room to a neighbour, maybe a panel): put the panels
  " back to their sizes; only a resize with the same windows is the user's own
  let shape = string(map(range(1, winnr('$')), 'win_getid(v:val)'))
  if shape !=# get(s:, 'shape', '')
    let s:shape = shape
    call timer_start(0, {-> s:Layout()})
    return
  endif
  let by_user = reltimefloat(reltime(get(s:, 'user_resize', [0, 0]))) < 1.5
  let moved = 0
  for id in get(v:event, 'windows', [])
    let n = win_id2win(id)
    let kind = n ? s:Kind(n) : ''
    if kind !=# '' && has_key(s:set, id)
      let size = kind ==# 'term' || kind ==# 'timeline' ? winheight(n) : winwidth(n)
      if size != s:set[id]
        if by_user
          let s:pref[kind] = size
          let s:set[id] = size
        else
          let moved = 1
        endif
      endif
    endif
  endfor
  if moved
    call timer_start(0, {-> s:Layout()})  " vim moved a panel's edge by itself: put it back
  endif
endfunction
" the user resizes: dragging an edge with the mouse, or Ctrl+w + - < > _ |
function! s:UserResize(keys) abort
  let s:user_resize = reltime()
  return a:keys
endfunction
for s:k in ['<LeftDrag>', '<LeftRelease>']
  execute 'nnoremap <expr>' s:k '<SID>UserResize("\' . s:k . '")'
  execute 'tnoremap <expr>' s:k '<SID>UserResize("\' . s:k . '")'
endfor
for s:k in ['+', '-', '<', '>', '_', '<Bar>']
  " (a count typed before stays in front of the keys: 5 Ctrl+w >)
  execute 'nnoremap <expr> <C-w>' . s:k '<SID>UserResize("\<C-w>' . s:k . '")'
endfor
function! s:PanelWidths(...) abort
  " a:1: a panel about to open ('ai' or 'tagbar'), counted as open
  let opening = get(a:, 1, '')
  let ft = map(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&filetype")') + [opening]
  let ai = bufwinnr(get(s:, 'ai', -1)) > 0 || opening ==# 'ai'
  let tree = index(ft, 'nerdtree') >= 0 || get(s:, 'tree_hidden', 0)
  for pass in [0, 1]
    let want = {'tree': tree ? s:PanelSize('tree') : 0,
          \ 'tagbar': index(ft, 'tagbar') >= 0 ? s:PanelSize('tagbar') : 0,
          \ 'ai': s:PanelSize('ai')}
    " shrink the outline first, then the tree, then the agent, until the editor has 40 columns
    for [k, least] in [['tagbar', 24], ['tree', 20], ['ai', 30], ['tagbar', 20]]
      let over = want.tree + want.tagbar + (ai ? want.ai : 0) - (&columns - 43)
      if over > 0 && want[k] && (k !=# 'ai' || ai)
        let want[k] = max([min([least, want[k]]), want[k] - over])
      endif
    endfor
    " an editor under 30 columns is not usable: the tree steps aside for the right-hand panels
    let want.fits = want.tree + want.tagbar + (ai ? want.ai : 0) <= &columns - 33
    if want.fits || !tree || !(want.tagbar || ai)
      let want.fits = 1
      break
    endif
    let tree = 0
  endfor
  let want.fits = tree || !(index(ft, 'nerdtree') >= 0 || get(s:, 'tree_hidden', 0))
  return want
endfunction
function! s:Layout(...) abort
  let here = win_getid()
  let want = s:PanelWidths(get(a:, 1, ''))
  let g:NERDTreeWinSize = s:PanelSize('tree')
  let tree = filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&filetype") ==# "nerdtree"')
  if !empty(tree)
    let s:tree_hidden = 0
    if !want.fits
      NERDTreeClose
      let s:tree_hidden = 1
    endif
  elseif get(s:, 'tree_hidden', 0) && want.fits
    let s:tree_hidden = 0
    NERDTreeToggle
  endif
  let s:shape = string(map(range(1, winnr('$')), 'win_getid(v:val)'))
  for n in range(1, winnr('$'))
    let kind = s:Kind(n)
    let id = win_getid(n)
    if kind ==# 'tree' || kind ==# 'tagbar' || kind ==# 'ai'
      call win_execute(id, 'vertical resize ' . want[kind])
      let s:set[id] = winwidth(n)
    elseif kind ==# 'timeline' && winnr(n . 'k') != n
      let column = winheight(winnr(n . 'k')) + winheight(n) + 1
      call win_execute(id, 'resize ' . min([s:PanelSize(kind), column / 2]))
      let s:set[id] = winheight(n)
    elseif kind ==# 'term' && (winnr(n . 'k') != n || winnr(n . 'j') != n)
      " only with a window above or below to trade rows with: resizing a full-height window
      " would hand the rows to the command line
      call win_execute(id, 'resize ' . s:PanelSize(kind))
      let s:set[id] = winheight(n)
    endif
  endfor
  if &cmdheight > 1
    set cmdheight=1
  endif
  call win_gotoid(here)
endfunction
" a new side panel is opened only after the others made room for it, so the editor is not squeezed
" to a sliver first
function! s:Outline() abort
  if index(map(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&filetype")'), 'tagbar') < 0
    call s:Layout('tagbar')
    let g:tagbar_width = s:PanelWidths('tagbar').tagbar
  endif
  TagbarToggle
  " tagbar closes itself when it is the last window from a WinEnter autocmd, which vim 9.2 refuses
  " (E1312); s:QuitIfOnlyPanels takes care of that case
  silent! autocmd! TagbarAutoCmds WinEnter *
  call s:Layout()
endfunction
function! s:Equalize() abort
  let s:pref = {}
  wincmd =
  call s:Layout()
endfunction
nnoremap <silent> <C-w>= :call <SID>Equalize()<CR>

" ─── tree sync, completion, terminals ────────────────────────────────────────────────────────────
" files created or removed outside vim (in the terminal, by git or a build) show up in the tree by
" themselves: the open folders whose modification time changed are read again
let s:tree_mtime = {}
let s:tree_gitdir = {}
function! s:TreeSync(...) abort
  if exists('g:NERDTree') && g:NERDTree.IsOpen() && mode() ==# 'n'
    " NERDTree's own functions only work from inside its window
    call win_execute(win_getid(g:NERDTree.GetWinNum()), 'call s:TreeSyncHere()')
  endif
endfunction
function! s:TreeSyncHere() abort
  if !exists('b:NERDTree')
    return
  endif
  let changed = 0
  let todo = [b:NERDTree.root]
  while !empty(todo)
    let node = remove(todo, 0)
    let dir = node.path.str()
    let t = getftime(dir)
    if get(s:tree_mtime, dir, t) != t
      call node.refresh()
      let changed = 1
    endif
    let s:tree_mtime[dir] = t
    call extend(todo, filter(copy(node.children), 'v:val.path.isDirectory && v:val.isOpen'))
  endwhile
  " git's own state: a commit, an add or a checkout done in a terminal
  let gitdir = get(s:tree_gitdir, getcwd(), '')
  if gitdir ==# '' && exists('*FugitiveExtractGitDir')
    let gitdir = FugitiveExtractGitDir(getcwd())
    let s:tree_gitdir[getcwd()] = gitdir
  endif
  let git = gitdir ==# '' ? [] : [getftime(gitdir . '/index'), getftime(gitdir . '/HEAD')]
  let git_changed = get(s:, 'tree_git', git) != git
  let s:tree_git = git
  if changed
    call b:NERDTree.render()
  endif
  " (and every 30 s at most otherwise: the plugin drops a result that arrives while the tree is
  " being reopened, which the next look then puts right)
  if changed || git_changed || localtime() - get(s:, 'tree_git_at', 0) >= 30
    let s:tree_git_at = localtime()
    silent! doautocmd <nomodeline> User FugitiveChanged
  endif
endfunction
augroup vimzip_treesync
  autocmd!
  autocmd CursorHold,FocusGained * call s:TreeSync()
  autocmd BufWritePost * call timer_start(0, function('s:TreeSync'))
  autocmd WinLeave * let s:from_term = &buftype ==# 'terminal'
  autocmd WinEnter * if get(s:, 'from_term', 0) | call timer_start(50, function('s:TreeSync')) | endif
augroup END

" keep the open tree pointed at the current file, like VSCode's explorer (focus stays in the editor)
function! s:RevealInTree() abort
  if &buftype !=# '' || !exists('g:NERDTree') || !g:NERDTree.IsOpen()
    return
  endif
  let f = expand('%:p')
  try
    let root = g:NERDTree.ForCurrentTab().root.path.str()
  catch
    return
  endtry
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
  let f = s:cache . '/words/' . s:CacheName(getcwd(), '.txt')
  if filereadable(f)
    call s:UseWords(f)
  endif
  let cmd = 'root=$(git -C ' . shellescape(getcwd()) . ' rev-parse --show-toplevel 2>/dev/null) || exit 1; '
        \ . (s:lite ? 'nice -n 10 ' : '') . 'rg -j ' . s:jobs
        \ . ' --no-filename --no-line-number --only-matching --max-filesize 1M' . s:src_types
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
    call s:Words()  " light mode builds the list only when it is first wanted
    return []
  endif
  let hits = systemlist('grep -m 200 ' . (&ignorecase ? '-i ' : '') . '-e '
        \ . shellescape('^' . escape(a:base, '.*[]\^$')) . ' ' . shellescape(s:words_file))
  return map(filter(hits, 'v:val !=# a:base'), {_, w -> {'word': w, 'menu': '[project]'}})
endfunction

" extra terminal next to the current window (below or right)
function! s:NewTerm(vert) abort
  if index(s:panels, &filetype) >= 0
    call s:EditWin()  " (beside the editor, not splitting the tree or the outline)
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

" ─── sessions and projects ───────────────────────────────────────────────────────────────────────
" per-folder session, used when started as `vim <dir>`
function! s:SessionFile() abort
  return s:cache . '/sessions/' . s:CacheName(getcwd(), '.vim')
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
    call s:DropGone()
  else
    enew
  endif
  if bufexists(dirbuf) && bufnr('') != dirbuf
    execute 'silent! bwipeout' dirbuf
  endif
  NERDTree
  wincmd p
  call s:Layout()
endfunction

" files of a restored session deleted since then do not come back as tabs (typing in one would
" save it, and its folders, again); the last one gives way to an empty tab
function! s:DropGone() abort
  for gone in filter(getbufinfo({'buflisted': 1}), 'v:val.name !=# "" && !filereadable(v:val.name) && !v:val.changed')
    if len(getbufinfo({'buflisted': 1})) > 1
      for w in gone.windows
        call win_execute(w, 'bprevious')
      endfor
    elseif !empty(gone.windows)
      call win_execute(gone.windows[0], 'enew')
      for w in gone.windows[1:]
        call win_execute(w, 'buffer ' . winbufnr(gone.windows[0]))
      endfor
    endif
    execute 'silent! bwipeout' gone.bufnr
  endfor
endfunction

function! s:Save() abort
  if !exists('s:session') | return | endif
  silent! NERDTreeClose
  silent! diffoff!
  for w in reverse(range(1, winnr('$')))
    " panels and git's views of a file (diffs, old versions) are not part of the session
    if winnr('$') > 1 && (getwinvar(w, '&buftype') !=# '' || bufname(winbufnr(w)) =~# '^\a\+://')
      execute w . 'close'
    endif
  endfor
  execute 'mksession!' fnameescape(s:session)
endfunction

" switch project in place (Space fp / :Project): save this one's tabs, close its tabs, terminals
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
  " and its language servers: ALE keeps one per project root running until vim quits
  silent! ALEStopAllLSPs
  execute 'cd' fnameescape(dir)
  let s:session = s:SessionFile()
  if filereadable(s:session)
    execute 'silent! source' fnameescape(s:session)
    call s:DropGone()
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
  let dirs = map(files, {_, f -> s:SessionDir(f)})
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
  " any terminal, also one from :terminal, ends with vim, like vimzip's own (++kill=hup): :qa or
  " :q in the last file stopped at E947 "Job still running", leaving the tree and the terminal
  call term_setkill(a:buf, 'hup')
  if bufnr('') == a:buf
    setlocal nonumber nocursorline signcolumn=no
  endif
endfunction

" ─── git marks at the window edge, tree hover ────────────────────────────────────────────────────
" git change marks at the right edge of each window, like VSCode's scrollbar: the whole file is
" scaled to the window height; one popup per window, transparent (masked) where there is no mark
for s:k in ['Add', 'Change', 'Delete']
  if empty(prop_type_get('vimzip_ruler_' . s:k))
    call prop_type_add('vimzip_ruler_' . s:k, {'highlight': 'VimzipRuler' . s:k})
  endif
endfor
let s:rulers = []
function! s:RulerLater(...) abort
  if get(s:, 'ruler_timer', -1) < 0
    let s:ruler_timer = timer_start(30, {-> s:Ruler()})
  endif
endfunction
function! s:Ruler() abort
  let s:ruler_timer = -1
  call map(s:rulers + filter(popup_list(), 'getwinvar(v:val, "vimzip_ruler", 0)'), 'popup_close(v:val)')
  let s:rulers = []
  let s:ruler_info = {}
  if !exists('g:loaded_gitgutter') | return | endif
  for w in gettabinfo(tabpagenr())[0].windows
    let b = winbufnr(w)
    let hunks = getbufvar(b, '&buftype') ==# '' ? gitgutter#hunk#hunks(b) : []
    let info = getwininfo(w)[0]
    if empty(hunks) || info.width < 20 | continue | endif
    let [h, n] = [info.height, max([info.height, getbufinfo(b)[0].linecount])]
    let marks = repeat([''], h)
    let target = {}
    for [_, old, start, new] in hunks
      let kind = old == 0 ? 'Add' : new == 0 ? 'Delete' : 'Change'
      let start = max([start, 1])
      for r in range((start - 1) * h / n, (start + max([new, 1]) - 2) * h / n)
        if r < h && (marks[r] ==# '' || kind ==# 'Change')
          let marks[r] = kind
        endif
        if r < h && !has_key(target, r)
          let target[r] = start
        endif
      endfor
    endfor
    let text = []
    let mask = []
    for r in range(h)
      if marks[r] ==# ''
        call add(text, {'text': ' '})
        if !empty(mask) && mask[-1][3] == r
          let mask[-1][3] = r + 1
        else
          call add(mask, [1, 1, r + 1, r + 1])
        endif
      else
        call add(text, {'text': '▐', 'props': [{'col': 1, 'length': 3, 'type': 'vimzip_ruler_' . marks[r]}]})
      endif
    endfor
    call add(s:rulers, popup_create(text, {'line': info.winrow, 'col': info.wincol + info.width - 1,
          \ 'minwidth': 1, 'maxwidth': 1, 'minheight': h, 'maxheight': h, 'wrap': 0, 'zindex': 1,
          \ 'highlight': 'VimzipRuler', 'mask': mask}))
    call setwinvar(s:rulers[-1], 'vimzip_ruler', 1)
    let s:ruler_info[s:rulers[-1]] = {'win': w, 'h': h, 'n': n, 'target': target}
  endfor
endfunction
" hidden while the text scrolls: with any popup on the screen vim redraws a scrolled window line by
" line instead of scrolling it (3x the output with a key held down, a terminal falling behind).
" Only where it can scroll: the full screen width, or with the terminal's margins (see t_CV).
function! s:RulerScroll() abort
  " the windows that scrolled (with the mouse wheel not always the current one)
  let wins = map(filter(keys(v:event), 'v:val =~# "^\\d\\+$" && v:event[v:val].topline'), 'win_id2win(str2nr(v:val))')
  if empty(s:rulers) || empty(filter(wins, '&t_CV !=# "" || winwidth(v:val) == &columns'))
    return
  endif
  call map(copy(s:rulers), 'popup_hide(v:val)')
  call timer_stop(get(s:, 'ruler_show', -1))
  let s:ruler_show = timer_start(300, {-> map(copy(s:rulers), 'popup_show(v:val)')})
endfunction
augroup vimzip_ruler
  autocmd!
  autocmd User GitGutter call s:RulerLater()
  autocmd WinResized,VimResized,WinClosed,TabEnter,BufWinEnter * call s:RulerLater()
  autocmd WinScrolled * call s:RulerScroll()
augroup END

" cache cleanup, at most once a day: regenerable caches (tags, words) go after 90 unused days,
" undo history and sessions after a year, or a month once their file or folder is gone
function! s:Prune(...) abort
  let stamp = s:cache . '/.pruned'
  if localtime() - getftime(stamp) < 86400 | return | endif
  call writefile([], stamp)
  let day = 86400
  let Path = {f -> substitute(fnamemodify(f, ':t:r'), '%', '/', 'g')}
  " (a hashed name, see s:CacheName, cannot be traced back to its file: it only ages)
  let Hashed = {f -> fnamemodify(f, ':t') !~# '%'}
  " (backup/: a save's safety copy is removed after it; one left over is from a save cut short)
  let rules = [['undo/*', 365, {f -> Hashed(f) || filereadable(substitute(fnamemodify(f, ':t'), '%', '/', 'g'))}],
        \      ['sessions/*.vim', 365, {f -> isdirectory(s:SessionDir(f))}],
        \      ['words/*.txt', 90, {f -> Hashed(f) || isdirectory(Path(f))}],
        \      ['systags/*.tags', 90, {f -> Hashed(f) || filereadable(Path(f))}],
        \      ['tags/*-tags', 90, {f -> 1}],
        \      ['words/*.tmp', 1, {f -> 0}], ['tags/*.temp', 1, {f -> 0}],
        \      ['backup/*', 7, {f -> 0}]]
  for [pat, days, Exists] in rules
    for f in glob(s:cache . '/' . pat, 1, 1)
      let age = (localtime() - getftime(f)) / day
      if age > days || (age > min([days, 30]) && !Exists(f))
        call delete(f)
      endif
    endfor
  endfor
endfunction
function! s:CacheSize() abort
  let total = 0
  for f in glob(s:cache . '/*/*', 1, 1)
    let total += max([0, getfsize(f)])
  endfor
  return total / 1048576
endfunction

" a file opened in a side panel's window (:e or :b typed in the tree) took the panel's place: the
" panel goes back, the file to the editor
let s:panels = ['nerdtree', 'tagbar', 'vimziptimeline']
function! s:KeepPanel(win, buf) abort
  let prev = getbufvar(a:buf, '&buftype') ==# '' ? win_execute(a:win, 'echon bufnr("#")') : ''
  if win_getid() != a:win || winbufnr(0) != a:buf || prev ==# '' || prev < 1
        \ || index(s:panels, getbufvar(str2nr(prev), '&filetype')) < 0
    return
  endif
  let editors = filter(range(1, winnr('$')), 'v:val != winnr() && getbufvar(winbufnr(v:val), "&buftype") ==# ""
        \ && index(s:panels, getbufvar(winbufnr(v:val), "&filetype")) < 0')
  if empty(editors)
    return
  endif
  let editor = index(map(copy(editors), 'win_getid(v:val)'), get(s:, 'editor', 0)) >= 0 ? s:editor : win_getid(editors[0])
  execute 'buffer' prev
  call win_gotoid(editor)
  execute 'buffer' a:buf
endfunction

augroup vimzip
  autocmd!
  autocmd BufEnter * let s:enter = [win_getid(), bufnr('')] | call timer_start(0, {-> s:KeepPanel(s:enter[0], s:enter[1])})
  autocmd VimEnter * call timer_start(5000, function('s:Prune'))
  autocmd VimEnter * call s:FastNERDTree()
  autocmd VimEnter * ++nested call s:Start()
  autocmd VimEnter * call timer_start(0, {-> s:GitGutterOn()})
  autocmd VimEnter,BufWritePost * if !s:lite | call s:Words() | endif
  autocmd VimLeavePre * call s:Save()
  autocmd TerminalOpen * call s:TermOpen(str2nr(expand('<abuf>')))
  autocmd User ALELintPost call s:BarRefresh()
  autocmd BufEnter * call timer_start(0, {-> s:QuitIfOnlyPanels()})
  autocmd WinClosed * call timer_start(0, {-> s:AfterClose()})
  " q closes fugitive's status and blame windows too (its own key is gq)
  autocmd FileType fugitive,fugitiveblame nmap <buffer> <silent> q gq
  " Ctrl+w s / v from a side panel split the editor, not the panel (a second file tree)
  autocmd FileType nerdtree,tagbar,vimziptimeline for s:k in ['s', 'S', 'v', '<C-s>', '<C-v>']
        \ | execute 'nnoremap <buffer> <silent> <C-w>' . s:k ':call <SID>EditWin()<Bar>' . (s:k =~? 'v' ? 'vsplit' : 'split') . '<CR>'
        \ | endfor
  " git's versions of a file (diffs, blame, history) stay out of the tabs
  autocmd BufReadPost fugitive://* setlocal nobuflisted
  " and so do the quickfix and location lists (Tab and Space q would show them in the editor)
  autocmd FileType qf setlocal nobuflisted
  " the timeline lives under the tree: it goes away and comes back with it
  autocmd BufWinLeave NERD_tree_* call timer_start(0, {-> s:TreeGone()})
  autocmd BufWinEnter NERD_tree_* call timer_start(0, {-> s:TreeBack()})
  " a timeline comparison left by opening another file in one of its windows (Tab, the tree, Ctrl+p)
  autocmd BufWinEnter * if get(s:tl, 'viewing', 0) && get(w:, 'vimzip_tl', 0) && bufname('') !~# '^fugitive://'
        \ && bufnr('') != bufnr(s:tl.file) | call timer_start(0, {-> s:TimelineCloseDiff(1)}) | endif
  autocmd BufEnter * call s:RevealInTree()
  autocmd BufWritePost * call timer_start(0, {-> s:RevealInTree()})
  autocmd FileType nerdtree call s:TreeIgnoredSyntax()
  " long names stay on one line, cut with … (the selected one is shown whole, see s:TreeHover)
  autocmd FileType nerdtree setlocal nowrap list listchars=extends:…
augroup END

" the selected tree line, when too long for the tree, shown whole in a popup laid over it
function! s:TreeHoverClose() abort
  if get(s:, 'hover', 0)
    call popup_close(s:hover)
    let s:hover = 0
  endif
endfunction
function! s:TreeHover() abort
  call s:TreeHoverClose()
  let line = getline('.')
  " what is drawn: without the node delimiters and the git flag's brackets (concealed)
  let shown = substitute(substitute(line, '\[\([^\]]*\)\]', '\1', ''), g:NERDTreeNodeDelimiter, '', 'g')
  let info = getwininfo(win_getid())[0]
  if strdisplaywidth(shown) < info.width - info.textoff || winsaveview().leftcol
    return
  endif
  let s:hover = popup_create(line, {'line': info.winrow + winline() - 1, 'col': info.wincol + info.textoff,
        \ 'highlight': 'CursorLine', 'zindex': 50, 'wrap': 0, 'padding': [0, 1, 0, 0]})
  call win_execute(s:hover, 'setlocal syntax=nerdtree conceallevel=3 concealcursor=nvic | call s:TreeIgnoredSyntax()')
endfunction
augroup vimzip_hover
  autocmd!
  autocmd CursorMoved,TextChanged,WinScrolled,WinEnter * if &filetype ==# 'nerdtree' | call s:TreeHover() | endif
  autocmd WinLeave * call s:TreeHoverClose()
augroup END

" ─── images and PDFs ─────────────────────────────────────────────────────────────────────────────
" Opened like any file (tree, Ctrl+p, :e), in a read-only tab: a picture drawn with half blocks,
" two pixels a cell (bin/vimzip-view), redrawn to fit when the window changes size; a PDF as its
" text (pdftotext when installed, else vimzip-view), to read, search and copy. o opens the file
" in the system viewer.
let s:view = $VIMZIP . '/bin/vimzip-view'
let s:img_hl = {}  " highlight group: its definition, again after a :colorscheme
function! s:ViewOpen(buf, kind) abort
  if bufname(a:buf) =~# '^fugitive://'
    " a version from git (timeline, Space gd): after fugitive has read it, from a copy of it
    call timer_start(0, {-> bufexists(a:buf) ? s:ViewGit(a:buf, a:kind) : 0})
    return
  endif
  let b:vimzip_view = a:kind
  setlocal buftype= noswapfile noundofile undolevels=-1 bufhidden= nomodeline
  let &l:filetype = 'vimzip' . a:kind
  silent! call gitgutter#buffer_disable(a:buf)
  nnoremap <buffer> <silent> o :call <SID>ViewExternal()<CR>
  call s:ViewFill(a:buf, ['', '  Loading ' . expand('%:t') . ' ...'])
  if a:kind ==# 'pdf'
    call s:PdfRead(a:buf)
  else
    unlet! b:vimzip_size
    call s:ImgRender(a:buf)
  endif
endfunction
function! s:ViewGit(buf, kind) abort
  let [rev, dir] = FugitiveParse(bufname(a:buf))
  let tmp = tempname() . '.' . fnamemodify(bufname(a:buf), ':e')
  call system('git --git-dir=' . shellescape(dir) . ' cat-file blob ' . shellescape(rev) . ' > ' . shellescape(tmp))
  call setbufvar(a:buf, 'vimzip_view', a:kind)
  call setbufvar(a:buf, 'vimzip_src', v:shell_error ? '' : tmp)
  call setbufvar(a:buf, 'vimzip_rev', rev =~# '^:' ? 'staged' : 'at ' . rev[: 6])
  call setbufvar(a:buf, '&filetype', 'vimzip' . a:kind)
  call win_execute(bufwinid(a:buf), 'setlocal ' . s:view_opts)
  call s:ViewFill(a:buf, ['', '  Loading ...'])
  if a:kind ==# 'pdf'
    call s:PdfRead(a:buf)
  else
    call s:ImgRender(a:buf)
  endif
endfunction
" the file to draw: the buffer's, or the copy taken from git
function! s:ViewFile(buf) abort
  return getbufvar(a:buf, 'vimzip_src', fnamemodify(bufname(a:buf), ':p'))
endfunction
function! s:ViewFill(buf, lines) abort
  call setbufvar(a:buf, '&modifiable', 1)
  silent call deletebufline(a:buf, 1, '$')
  call setbufline(a:buf, 1, a:lines)
  call setbufvar(a:buf, '&modifiable', 0)
  call setbufvar(a:buf, '&modified', 0)
endfunction
function! s:ViewHeader(buf, info) abort
  let kb = getfsize(s:ViewFile(a:buf)) / 1024
  let name = fnamemodify(bufname(a:buf), ':t') . (getbufvar(a:buf, 'vimzip_rev') !=# '' ? ' (' . getbufvar(a:buf, 'vimzip_rev') . ')' : '')
  return printf('  %s   %s   %s   o: open in viewer', name, a:info,
        \ kb >= 1024 ? printf('%.1f MB', kb / 1024.0) : max([kb, 1]) . ' KB')
endfunction
" the window's size in cells for the picture, under the header line and a blank one
function! s:ImgRender(buf) abort
  let w = bufwinid(a:buf)
  if w < 0 || getbufvar(a:buf, 'vimzip_view') !=# 'image'
    return
  endif
  let size = [max([4, winwidth(w) - 2]), max([2, winheight(w) - 3])]
  if getbufvar(a:buf, 'vimzip_size', []) == size
    return
  endif
  call setbufvar(a:buf, 'vimzip_size', size)
  if !executable(s:view)
    call s:ViewFill(a:buf, ['', '  vimzip-view is missing from ' . fnamemodify(s:view, ':h') . ': o opens the picture elsewhere'])
    return
  endif
  let out = []
  let cmd = [s:view, 'image', s:ViewFile(a:buf), size[0], size[1]] + (&termguicolors ? [] : ['256'])
  call job_start(cmd, {'out_cb': {_, l -> add(out, l)}, 'err_cb': {_, l -> add(out, 'error: ' . l)},
        \ 'close_cb': {_ -> s:ImgShow(a:buf, out, size)}})
endfunction
function! s:ImgShow(buf, out, size) abort
  if !bufexists(a:buf) || getbufvar(a:buf, 'vimzip_size', []) != a:size
    return  " gone, or resized again while drawing
  endif
  if empty(a:out) || a:out[0] =~# '^error: '
    let msg = empty(a:out) ? 'no output' : substitute(a:out[0], '^error: \(vimzip-view: \)\=', '', '')
    call s:ViewFill(a:buf, [s:ViewHeader(a:buf, 'cannot be shown'), '', '  ' . msg])
    return
  endif
  let [dims, format] = split(a:out[0] . ' ?')[0 : 1]
  let lines = [s:ViewHeader(a:buf, format . ' ' . substitute(dims, 'x', ' x ', '')), '']
  let props = []
  let gui = &termguicolors
  for row in a:out[1 :]
    let runs = map(split(row), 'split(v:val, ":")')
    let width = eval(join(map(copy(runs), 'v:val[0]'), '+'))
    let text = repeat(' ', max([0, (a:size[0] - width) / 2]) + 1)
    for [n, top, bottom] in runs
      let name = 'VimzipImg_' . top . '_' . bottom
      if !has_key(s:img_hl, name)
        let s:img_hl[name] = gui ? printf('guifg=#%s guibg=#%s', top, bottom) : printf('ctermfg=%s ctermbg=%s', top, bottom)
        execute 'highlight' name s:img_hl[name]
        call prop_type_add(name, {'highlight': name})
      endif
      call add(props, [len(lines) + 1, len(text) + 1, str2nr(n) * 3, name])
      let text .= repeat('▀', str2nr(n))
    endfor
    call add(lines, text)
  endfor
  call s:ViewFill(a:buf, lines)
  for [lnum, col, length, name] in props
    call prop_add(lnum, col, {'length': length, 'type': name, 'bufnr': a:buf})
  endfor
endfunction
function! s:PdfRead(buf) abort
  let file = s:ViewFile(a:buf)
  let cmd = executable('pdftotext') ? ['pdftotext', '-layout', '-enc', 'UTF-8', file, '-'] : [s:view, 'pdf', file]
  let [out, err] = [[], []]
  call job_start(cmd, {'out_cb': {_, l -> add(out, l)}, 'err_cb': {_, l -> add(err, l)},
        \ 'close_cb': {_ -> s:PdfShow(a:buf, out, err, fnamemodify(cmd[0], ':t'))}})
endfunction
" pages are separated by form feeds: a line for each new page instead
function! s:PdfShow(buf, out, err, tool) abort
  if !bufexists(a:buf)
    return
  endif
  let pages = [[]]
  for l in a:out
    let parts = split(l, "\f", 1)
    call add(pages[-1], parts[0])
    for p in parts[1 :]
      call add(pages, p ==# '' ? [] : [p])
    endfor
  endfor
  if len(pages) > 1 && empty(filter(copy(pages[-1]), 'v:val !~# "^\\s*$"'))
    call remove(pages, -1)  " pdftotext ends the last page with one too
  endif
  let lines = [s:ViewHeader(a:buf, len(pages) . (len(pages) == 1 ? ' page' : ' pages') . ', text by ' . a:tool)]
  if empty(filter(copy(a:out), 'v:val =~# "\\S"'))
    call extend(lines, ['', '  ' . (empty(a:err) ? 'No text in this PDF (scanned pages are pictures).' : a:err[0])])
  else
    for i in range(len(pages))
      call extend(lines, ['', '── page ' . (i + 1) . ' ' . repeat('─', 60), ''] + pages[i])
    endfor
  endif
  call s:ViewFill(a:buf, lines)
endfunction
function! s:ViewExternal() abort
  let f = s:ViewFile(bufnr(''))
  if executable('wslpath') && executable('explorer.exe') && !executable('wslview')
    let cmd = ['explorer.exe', trim(system('wslpath -w ' . shellescape(f)))]
  else
    " (not open: on some Linux systems that is openvt, which starts a console)
    let cmd = map(filter(['xdg-open', 'wslview'], 'executable(v:val)')[: 0], '[v:val, f]')
    let cmd = empty(cmd) ? [] : cmd[0]
  endif
  if empty(cmd)
    echohl WarningMsg | echo 'No system viewer here (xdg-open), e.g. over ssh' | echohl None
    return
  endif
  call job_start(cmd, {'stoponexit': '', 'in_io': 'null', 'out_io': 'null', 'err_io': 'null'})
  echo 'Opened in the system viewer: ' . expand('%:t')
endfunction
" no line numbers or cursor line over a picture; redrawn to fit after a resize
let s:view_opts = 'nonumber norelativenumber nocursorline nolist nowrap signcolumn=no colorcolumn= foldcolumn=0'
function! s:ViewWindow() abort
  if exists('b:vimzip_view')
    execute 'setlocal' s:view_opts
    call s:ImgRender(bufnr(''))
  endif
endfunction
let s:view_files = '*.{png,PNG,jpg,JPG,jpeg,JPEG,gif,GIF,webp,WEBP,bmp,BMP,tif,TIF,tiff,TIFF}'
augroup vimzip_view
  autocmd!
  execute 'autocmd BufReadCmd' s:view_files 'call s:ViewOpen(str2nr(expand("<abuf>")), "image")'
  autocmd BufReadCmd *.{pdf,PDF} call s:ViewOpen(str2nr(expand('<abuf>')), 'pdf')
  " never write the drawing or the text over the file
  execute 'autocmd BufWriteCmd' s:view_files . ',*.{pdf,PDF} echohl WarningMsg | echo "Read-only view" | echohl None'
  autocmd BufWinEnter * call s:ViewWindow()
  autocmd WinResized,VimResized * for s:w in gettabinfo(tabpagenr())[0].windows | call s:ImgRender(winbufnr(s:w)) | endfor
  autocmd ColorScheme * for [s:n, s:d] in items(s:img_hl) | execute 'highlight' s:n s:d | endfor
augroup END

" ─── keys ────────────────────────────────────────────────────────────────────────────────────────
" keys: vim's own keys where vim has one (gd, gr, K, ]c, ]e, Ctrl+w ...), VSCode's F-keys and
" Ctrl+ combinations, and Space + a letter per group (f find, g git, c code, t terminal, d debug)

" find: Space f
nnoremap <silent> <C-p> :call <SID>Buf('Files')<CR>
nnoremap <silent> <C-S-f> :call <SID>Buf('Find')<CR>
xnoremap <silent> <C-S-f> <Esc>:call <SID>FindText(<SID>Selection())<CR>
nnoremap <silent> <leader>ff :call <SID>Buf('Files')<CR>
nnoremap <silent> <leader>fs :call <SID>Buf('Find')<CR>
xnoremap <silent> <leader>fs <Esc>:call <SID>FindText(<SID>Selection())<CR>
nnoremap <silent> <leader>fw :call <SID>FindText(expand('<cword>'))<CR>
xnoremap <silent> <leader>fw <Esc>:call <SID>FindText(<SID>Selection())<CR>
nnoremap <silent> <leader>fb :call <SID>Buf('Buffers')<CR>
nnoremap <silent> <leader>fr :call <SID>Buf('History')<CR>
nnoremap <silent> <leader>ft :call <SID>Buf('Tags')<CR>
nnoremap <silent> <leader>fp :call <SID>PickProject()<CR>
function! s:Selection() abort
  return join(getregion(getpos("'<"), getpos("'>"), {'type': visualmode()}), "\n")
endfunction

" tabs and files
nnoremap <silent> <Tab> :call <SID>Buf('bnext')<CR>
nnoremap <silent> <S-Tab> :call <SID>Buf('bprevious')<CR>
nnoremap <silent> <leader>q :call <SID>CloseBuf()<CR>
nnoremap <silent> <C-s> :update<CR>
inoremap <silent> <C-s> <C-o>:update<CR>
xnoremap <silent> <C-s> <Esc>:update<CR>
xnoremap <C-c> y

" panels: Space e explorer, Space o outline, Space a AI agent (and VSCode's keys)
nnoremap <silent> <F2> :call <SID>Explorer()<CR>
nnoremap <silent> <C-S-e> :call <SID>Explorer()<CR>
tnoremap <silent> <C-S-e> <C-w>:call <SID>Explorer()<CR>
nnoremap <silent> <leader>e :call <SID>Explorer()<CR>
nnoremap <silent> <F3> :call <SID>Outline()<CR>
nnoremap <silent> <leader>o :call <SID>Outline()<CR>
nnoremap <silent> <C-M-i> :call <SID>ToggleAi()<CR>
tnoremap <silent> <C-M-i> <C-w>:call <SID>ToggleAi()<CR>
nnoremap <silent> <leader>a :call <SID>ToggleAi()<CR>

" terminal: Space t; inside a terminal Ctrl+w s / v open another one below / beside (like windows)
nnoremap <silent> <F4> :call <SID>ToggleTerm()<CR>
tnoremap <silent> <F4> <C-w>:call <SID>ToggleTerm()<CR>
nnoremap <silent> <leader>tt :call <SID>ToggleTerm()<CR>
nnoremap <silent> <leader>ts :call <SID>NewTerm(0)<CR>
nnoremap <silent> <leader>tv :call <SID>NewTerm(1)<CR>
tnoremap <silent> <C-w>s <C-w>:call <SID>NewTerm(0)<CR>
tnoremap <silent> <C-w>v <C-w>:call <SID>NewTerm(1)<CR>

" windows: vim's Ctrl+w keys (s / v split, q close, = equal ...), plus Ctrl+h/j/k/l to move
" Ctrl+w s / v / n in a side panel split the editor instead (a split tree or terminal is no use)
for s:k in ['s', 'v', 'n', '<C-s>', '<C-v>', '<C-n>']
  execute 'nnoremap <silent> <C-w>' . s:k ':<C-u>call <SID>EditWin()<Bar>execute "wincmd ' . (s:k =~# 's' ? 's' : s:k =~# 'v' ? 'v' : 'n') . '"<CR>'
endfor
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" code: vim's gd / gr / K / ]e [e, VSCode's F12, Space c for the rest
nnoremap <silent> <F12> :call <SID>GoDef()<CR>
nnoremap <silent> gd :call <SID>GoDef()<CR>
" :Man page (K without a language server)
if executable('man')
  runtime ftplugin/man.vim
endif
" with a language server: its references and hover; otherwise the word searched in the project
" (vim's own gr would start overwriting text) and the man page in a split
function! s:Refs() abort
  if s:LspHere()
    ALEFindReferences
  else
    call s:FindText(expand('<cword>'))
  endif
endfunction
function! s:Docs() abort
  if s:LspHere()
    ALEHover
  elseif exists(':Man') == 2
    if expand('<cword>') !=# ''  " (on a blank, :Man stopped at "E471: Argument required")
      execute 'Man' expand('<cword>')
    endif
  else
    echo 'No documentation: a language server (:Lsp) or man is needed'
  endif
endfunction
nnoremap <silent> gr :call <SID>Refs()<CR>
nnoremap <silent> K :call <SID>Docs()<CR>
nmap ]e <Plug>(ale_next_wrap)
nmap [e <Plug>(ale_previous_wrap)
nnoremap <silent> <leader>ce :ALEDetail<CR>
nnoremap <silent> <leader>cl :Lsp<CR>
nnoremap <silent> <leader>cf gg=G``

" git: Space g; ]c / [c move between changes (vim's keys for that in a diff)
" outside a git repository: one line saying so (Space gd stopped at a press-ENTER error)
function! s:InGit() abort
  if empty(FugitiveGitDir())
    echohl WarningMsg | echo 'Not in a git repository' | echohl None
    return 0
  endif
  return 1
endfunction
" (a command run from here: :Git in a mapping's if ... endif took the endif as its own)
" a:1: about the current file's history, which a new file git does not know has none (the
" comparison was empty, the commit popup silent, blame a "fatal:" line)
function! s:GitRun(cmd, ...) abort
  if !s:InGit()
    return
  endif
  if get(a:, 1, 0) && &buftype ==# '' && filereadable(expand('%:p'))
    call system('git -C ' . shellescape(expand('%:p:h')) . ' ls-files --error-unmatch -- ' . shellescape(expand('%:t')))
    if v:shell_error
      echohl WarningMsg | echo expand('%:t') . ' is not in git yet' | echohl None
      return
    endif
  endif
  execute a:cmd
endfunction
nnoremap <silent> <leader>gs :call <SID>EditWin()<Bar>call <SID>GitRun('Git')<CR>
nnoremap <silent> <leader>gc :call <SID>EditWin()<Bar>call <SID>GitRun('call <SID>CommitPopup()', 1)<CR>
nnoremap <silent> <leader>gb :call <SID>EditWin()<Bar>let g:vimzip_blame = !g:vimzip_blame <Bar> call <SID>Blame()<CR>
nnoremap <silent> <leader>gB :call <SID>EditWin()<Bar>call <SID>GitRun('Git blame', 1)<CR>
nnoremap <silent> <leader>gh :call <SID>EditWin()<Bar>GV!<CR>
xnoremap <silent> <leader>gh :GV<CR>
nnoremap <silent> <leader>gl :call <SID>EditWin()<Bar>GV<CR>
nnoremap <silent> <leader>gt :call <SID>ToggleTimeline()<CR>
" side by side, or one above the other when the window is too narrow for two
function! s:DiffSplit(mods, rev) abort
  try
    if exists('b:vimzip_view')
      " a picture or PDF: the other version beside it (a line diff of the drawing means nothing)
      execute (a:mods ==# '' ? 'leftabove' : a:mods) 'Gvsplit' (a:rev ==# '' ? ':%' : a:rev . ':%')
      return
    endif
    execute a:mods . ' ' . (winwidth(0) >= 54 ? 'Gvdiffsplit' : 'Gdiffsplit') . ' ' . a:rev
  catch /E36:/
    echohl WarningMsg | echo 'No room to compare: close a panel or split' | echohl None
  endtry
endfunction
nnoremap <silent> <leader>gd :call <SID>EditWin()<Bar>call <SID>GitRun('call <SID>DiffSplit("", "")', 1)<CR>
nmap <silent> <leader>gp :call <SID>EditWin()<CR><Plug>(GitGutterPreviewHunk)
nmap <silent> <leader>ga :call <SID>EditWin()<CR><Plug>(GitGutterStageHunk)
nmap <silent> <leader>gu :call <SID>EditWin()<CR><Plug>(GitGutterUndoHunk)
nmap <silent> <expr> ]c &diff ? ']c' : '<Plug>(GitGutterNextHunk)'
nmap <silent> <expr> [c &diff ? '[c' : '<Plug>(GitGutterPrevHunk)'

" Space ?: every key on one page (autoload/vimzip/keys.vim)
nnoremap <silent> <leader>? :call vimzip#keys#show()<CR>

" the same keys while typing or selecting (unmapped, vim would type "<F4>" into the file)
for s:k in ['<F2>', '<F3>', '<F4>', '<F5>', '<F10>', '<F11>', '<F12>', '<C-S-f>', '<C-S-e>', '<C-M-i>']
  execute 'imap <silent>' s:k '<Esc>' . s:k
  if s:k !=# '<C-S-f>'
    execute 'xmap <silent>' s:k '<Esc>' . s:k
  endif
endfor
tnoremap <silent> <C-S-f> <C-w>:call <SID>Buf('Find')<CR>
" Terminals that send nothing special for Ctrl+Shift+letter send plain Ctrl+letter, and vim then
" matches the Ctrl+Shift mappings on it: Ctrl+f (page down, or forward a character in a shell) would
" open the search and Ctrl+e (scroll, end of line) the tree. These come after, so plain Ctrl+f / e
" keep their own meaning; a real Ctrl+Shift code still reaches the mappings above.
for s:m in ['n', 'x', 'i', 't']
  execute s:m . 'noremap <C-f> <C-f>'
  execute s:m . 'noremap <C-e> <C-e>'
endfor
" ─── debugger ────────────────────────────────────────────────────────────────────────────────────
" debugger (termdebug): F5 start/continue, F9 breakpoint, F10 over, F11 step
function! s:Debug() abort
  if exists(':RunOrContinue') == 2
    RunOrContinue
  else
    call s:EditWin()  " (termdebug splits the current window: not the tree's)
    call feedkeys(':TermdebugCommand ', 'n')
  endif
endfunction
" breakpoints set before the debugger runs are kept as signs and handed to gdb when it starts;
" then the program runs right away (stopping at them) and the cursor goes back to the source
highlight default VimzipBreak ctermfg=167 guifg=#d75f5f
call sign_define('vimzip_break', {'text': '●', 'texthl': 'VimzipBreak'})
function! s:ToggleBreak() abort
  if exists(':ToggleBreak') == 2
    ToggleBreak
    return
  endif
  let placed = sign_getplaced(bufnr(''), {'group': 'vimzip_break', 'lnum': line('.')})[0].signs
  if empty(placed)
    call sign_place(0, 'vimzip_break', 'vimzip_break', bufnr(''), {'lnum': line('.'), 'priority': 120})
  else
    call sign_unplace('vimzip_break', {'buffer': bufnr(''), 'id': placed[0].id})
  endif
endfunction
function! s:DebugStarted() abort
  for b in getbufinfo({'buflisted': 1})
    for sign in sign_getplaced(b.bufnr, {'group': 'vimzip_break'})[0].signs
      execute 'Break' fnameescape(fnamemodify(b.name, ':p')) . ':' . sign.lnum
    endfor
  endfor
  call sign_unplace('vimzip_break')
  " termdebug splits the editor in half for gdb and the program, which next to the tree leaves the
  " source a narrow strip of wrapped lines: the source gets the larger part
  let tree = filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), "&filetype") ==# "nerdtree"')
  let room = &columns - (empty(tree) ? 0 : winwidth(tree[0]) + 1)
  for name in ['gdb', 'debugged-program']
    let w = bufwinid(bufnr('^' . name . '$'))
    if w > 0
      call win_execute(w, 'vertical resize ' . max([40, min([90, room * 2 / 5])]))
    endif
  endfor
  Run
  Source
endfunction
augroup vimzip_debug
  autocmd!
  autocmd User TermdebugStartPost call s:DebugStarted()
augroup END
nnoremap <silent> <F5> :call <SID>Debug()<CR>
nnoremap <silent> <F9> :call <SID>ToggleBreak()<CR>
inoremap <silent> <F9> <C-o>:call <SID>ToggleBreak()<CR>
nnoremap <silent> <F10> :silent! Over<CR>
nnoremap <silent> <F11> :silent! Step<CR>
nnoremap <silent> <S-F11> :silent! Finish<CR>
" the same on Space d, for terminals that keep the F-keys for themselves
nnoremap <silent> <leader>dd :call <SID>Debug()<CR>
nnoremap <silent> <leader>db :call <SID>ToggleBreak()<CR>
nnoremap <silent> <leader>dn :silent! Over<CR>
nnoremap <silent> <leader>di :silent! Step<CR>
nnoremap <silent> <leader>do :silent! Finish<CR>

" ─── personal overrides ──────────────────────────────────────────────────────────────────────────
" personal overrides
let s:blame_default = g:vimzip_blame
if filereadable(expand('~/.config/vimzip/vimrc'))
  execute 'source' fnameescape(expand('~/.config/vimzip/vimrc'))
endif

" ─── light mode ─────────────────────────────────────────────────────────────────────────────────
" On a small machine (s:res, under 2 CPUs or 1 GB free) do less in the background: line blame
" starts off (Space gb), files are checked when saved rather than also when opened, the change
" marks refresh less often, the completion word list is built when
" first used, clangd runs without its background index, and under 1 GB free language servers
" start off (:Lsp turns one on).
" :VimzipInfo shows what was found and chosen.
function! s:Light() abort
  let auto = s:res.cpus < 2 || s:res.mem < 1024
  let s:lite = exists('g:vimzip_lite') ? g:vimzip_lite : $VIMZIP_LITE !=# '' ? str2nr($VIMZIP_LITE) : auto
  call s:LspSetup()
  if !s:lite
    return
  endif
  set updatetime=1000
  if g:vimzip_blame == s:blame_default
    let g:vimzip_blame = 0
  endif
  let g:ale_lint_on_enter = 0
  let g:ale_c_clangd_options = '--background-index=false -j=1'
  let g:ale_cpp_clangd_options = g:ale_c_clangd_options
endfunction
call s:Light()
function! s:Info() abort
  echo printf('CPUs %.1f, free memory %d MB: %s mode', s:res.cpus, s:res.mem, s:lite ? 'light' : 'full')
  echo printf('rg threads %d, line blame %s, lint %s', s:jobs,
        \ g:vimzip_blame ? 'on' : 'off', get(g:, 'ale_lint_on_enter', 1) ? 'on open and save' : 'on save')
  let on = map(filter(copy(s:servers), 's:LspState(v:val)[0] ==# "on"'), 'v:val[1] . " (" . s:LspState(v:val)[1] . ")"')
  echo 'language servers: ' . (empty(on) ? 'none on' : join(on, ', ')) . ' (:Lsp to change)'
  echo printf('cache %d MB in %s (old entries are removed daily)', s:CacheSize(), fnamemodify(s:cache, ':~'))
  if s:lite
    echo 'g:vimzip_lite = 0 in ~/.config/vimzip/vimrc turns light mode off'
  endif
endfunction
command! -bar VimzipInfo call s:Info()
call s:Highlights()
