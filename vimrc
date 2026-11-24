" vimzip: a portable, VSCode-like vim. Sections: basics, theme, code, git, timeline, search,
" tree, status bar, windows, panels, terminals, projects, git marks, keys, debugger.
set nocompatible
let &packpath = $VIMZIP . ',' . $VIMRUNTIME
let &runtimepath = $VIMZIP . ',' . $VIMRUNTIME . ',' . $VIMRUNTIME . '/after'
let s:cache = expand('~/.cache/vimzip')
for s:d in ['undo', 'sessions', 'tags', 'systags', 'words', 'backup', 'cmake']
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
" vim's plugins no one here uses (vimball archives, :GLVS, LogiPat, :TOhtml): not loaded at start
let [g:loaded_vimballPlugin, g:loaded_getscriptPlugin, g:loaded_logiPat, g:loaded_rrhelper] = [1, 1, 1, 1]
let g:loaded_2html_plugin = 1
packadd! comment
packadd! editorconfig
packadd! matchit
packadd osc52

filetype plugin indent on
syntax on

" ─── basics ──────────────────────────────────────────────────────────────────────────────────────
" basics
set encoding=utf-8 fileencodings=ucs-bom,utf-8,cp949,latin1
" a file that ends without a newline keeps it so, like VSCode: saved automatically after any edit,
" it otherwise gained one, a change in git nobody made (.editorconfig's insert_final_newline wins)
set nofixendofline
" Ctrl+a on 007 gives 008, not octal 010 (defaults.vim, which -u skips, does the same)
set nrformats-=octal
set autoindent smarttab tabstop=4 shiftwidth=4
" indentation as the file already has it, like VSCode: spaces or tabs, and how many spaces (Tab
" and >> put tabs into a file indented with two spaces). An .editorconfig still decides (its
" plugin runs after this); Makefiles need their tabs.
function! s:DetectIndent() abort
  if &buftype !=# '' || exists('b:vimzip_view') || &filetype ==# 'make'
    return
  endif
  let [tabs, spaces, steps, prev] = [0, 0, {}, 0]
  for l in getline(1, 1000)
    if l =~# '^\s*$'
      continue
    endif
    let lead = matchstr(l, '^[ \t]*')
    if lead[0] ==# "\t"
      let tabs += 1
      let prev = 0
      continue
    endif
    let n = len(lead)
    if n >= 2 && l[n] !=# '*'  " (not the ' * ' of a C comment)
      let spaces += 1
    endif
    if n > prev && n - prev <= 8
      let steps[n - prev] = get(steps, n - prev, 0) + 1
    endif
    let prev = n
  endfor
  if tabs > spaces
    setlocal noexpandtab
  elseif spaces > tabs && spaces >= 2
    let best = 0
    for n in [2, 4, 3, 8]
      if get(steps, n, 0) > get(steps, best, 0)
        let best = n
      endif
    endfor
    if best
      execute 'setlocal expandtab shiftwidth=' . best . ' softtabstop=' . best
    endif
  endif
endfunction
augroup vimzip_indent
  autocmd!
  autocmd BufReadPost * call s:DetectIndent()
  " a file opened again starts where it was left (vim's defaults.vim does this, which -u skips);
  " not a commit message, which is new each time
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line('$') && &filetype !~# '^git\(commit\|rebase\)$'
        \ && expand('<afile>') !~# '^\a\+://' | execute 'normal! g`"' | endif
augroup END
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
      let s:autosaving = 1
      silent update
    catch
      echohl ErrorMsg
      echomsg (&modified ? 'Not saved: ' : 'Saved, but: ') . substitute(v:exception, '^Vim(\a\+):', '', '')
      echohl None
    finally
      let s:autosaving = 0
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
  highlight! link VimzipBarProblems VimzipBar
  highlight! link VimzipBarBranch VimzipBar
  " the word under the cursor elsewhere, brackets by depth, sticky lines, peek, Markdown preview
  highlight VimzipWord ctermbg=237 guibg=#343a40 cterm=NONE gui=NONE
  highlight VimzipBracket1 ctermfg=220 guifg=#ffd700
  highlight VimzipBracket2 ctermfg=170 guifg=#da70d6
  highlight VimzipBracket3 ctermfg=39 guifg=#179fff
  highlight VimzipSticky ctermbg=235 guibg=#252526
  highlight VimzipPeekLine ctermbg=237 guibg=#2f3a45
  highlight VimzipMdH1 ctermfg=75 guifg=#4fc1ff cterm=bold gui=bold
  highlight VimzipMdH2 ctermfg=75 guifg=#4fc1ff cterm=bold gui=bold
  highlight VimzipMdBold cterm=bold gui=bold
  highlight VimzipMdItalic cterm=italic gui=italic
  highlight VimzipMdCode ctermfg=174 ctermbg=236 guifg=#ce9178 guibg=#2d2d2d
  highlight VimzipMdLink ctermfg=75 guifg=#3794ff cterm=underline gui=underline
  highlight VimzipMdDim ctermfg=241 guifg=#5a5a5a
  highlight VimzipMdBlock ctermbg=235 guibg=#252526
  " several places at once (Ctrl+n), find and replace, merge conflicts
  highlight VimzipMulti ctermfg=231 ctermbg=24 guifg=#ffffff guibg=#264f78 cterm=NONE gui=NONE
  highlight VimzipReplaceOld ctermfg=210 ctermbg=52 guifg=#f48771 guibg=#4b1818 cterm=strikethrough gui=strikethrough
  highlight VimzipReplaceNew ctermfg=114 ctermbg=22 guifg=#9ccc65 guibg=#1f3a1f cterm=NONE gui=NONE
  highlight link VimzipReplaceHead Title
  highlight VimzipConflictMark ctermbg=237 guibg=#3c3c3c
  highlight VimzipConflictCurrent ctermbg=23 guibg=#1e3b33
  highlight VimzipConflictIncoming ctermbg=17 guibg=#1b2e4b
  highlight VimzipConflictHint ctermfg=245 guifg=#8a8a8a cterm=italic gui=italic
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
" code in VSCode's Dark+ colors (colors/vimzip.vim); :colorscheme habamax (or any other) in
" ~/.config/vimzip/vimrc for vim's own look
silent! colorscheme vimzip

" what vim's syntax files leave alike, told apart as VSCode does: function names (before a
" parenthesis), members (after . or ->), types (CamelCase in languages with classes, t_x / x_t in
" C), CONSTANTS, and the other names as variables. Keywords stay keywords: vim's :syntax keyword
" always wins over a match.
let s:code_syntax = {'c': 'c', 'cpp': 'cpp', 'java': 'class', 'cs': 'pascal', 'kotlin': 'class',
      \ 'scala': 'class', 'swift': 'class', 'dart': 'class', 'php': 'class', 'python': 'class',
      \ 'rust': 'class', 'javascript': 'class', 'typescript': 'ts', 'javascriptreact': 'class',
      \ 'typescriptreact': 'ts', 'go': 'pascal', 'lua': '', 'zig': ''}
" words that are keywords there although the syntax file matches them some other way
let s:code_skip = {
      \ 'lua': 'and\|break\|do\|else\|elseif\|end\|false\|for\|function\|goto\|if\|in\|local\|nil\|not\|or\|repeat\|return\|then\|true\|until\|while',
      \ 'cs': 'class\|struct\|interface\|enum\|record\|namespace\|delegate\|event',
      \ 'zig': '[iuf]\d\+\|usize\|isize\|bool\|void\|type\|anyerror\|anytype\|noreturn\|comptime_int\|comptime_float',
      \ 'go': 'package\|import\|const\|var\|type\|func\|struct\|interface\|map\|chan\|go\|defer\|select\|range\|return\|if\|else\|for\|switch\|case\|default\|break\|continue\|goto\|fallthrough'}
function! s:CodeSyntax() abort
  let kind = get(s:code_syntax, &syntax, -1)
  " (another colorscheme in the vimrc: vim's own look, as that scheme colors it)
  if kind is -1 || exists('b:vimzip_view') || get(g:, 'colors_name', '') !=# 'vimzip'
    return
  endif
  if kind ==# 'ts'
    " TypeScript's syntax names most things itself (see colors/vimzip.vim); its plain names and
    " properties are transparent, so the colors go inside them
    syntax match vimzipVariable /\<\h\w*\>/ display contained containedin=typescriptIdentifierName
    syntax match vimzipMember /\<\h\w*\>/ display contained containedin=typescriptProp
    syntax match vimzipFunction /\<\h\w*\ze\s*(/ display contained containedin=typescriptIdentifierName,typescriptProp,typescriptMember
    syntax match vimzipConstant /\<\u[A-Z0-9_]\+\>/ display contained containedin=typescriptIdentifierName,typescriptVariableDeclaration
    " (and its names for the methods and properties of the DOM, console, arrays...)
    for g in getcompletion('typescript', 'highlight')
      if g =~# '\a\(Method\|Prop\)$'
        let to = g =~# 'Method$' ? 'vimzipFunction' : 'vimzipMember'
        execute 'highlight! link' g to
      endif
    endfor
  else
    " defined before the syntax file's own items: where one of those starts at the same place (a
    " keyword written as a match, R"(raw)", f"{x}", a label, a macro!), it still wins
    syntax clear
    let skip = has_key(s:code_skip, &syntax) ? '\%(\<\%(' . s:code_skip[&syntax] . '\)\>\)\@!' : ''
    " (PHP: code only between <?php and ?>, not the page around it)
    let in = &syntax ==# 'php' ? ' contained containedin=phpRegion,phpRegionSc,phpRegionAsp' : ''
    execute 'syntax match vimzipVariable /' . skip . '\<\h\w*\>/ display' . in
    if kind ==# 'pascal'
      " (Go, C#: functions are CamelCase too; a call stays a function)
      execute 'syntax match vimzipType /\<\u\w*\l\w*\>/ display' . in
    endif
    execute 'syntax match vimzipMember /\%(\.\|->\)\s*\zs\h\w*\>/ display' . in
    execute 'syntax match vimzipFunction /' . skip . '\<\h\w*\ze\s*(/ display' . in
    if kind ==# 'class' || kind ==# 'cpp'
      execute 'syntax match vimzipType /\<\u\w*\l\w*\>/ display' . in
    endif
    if kind ==# 'c' || kind ==# 'cpp'
      syntax match vimzipType /\<\%([ts]_\h\w*\|\h\w*_t\)\>/ display
    endif
    if kind ==# 'cpp'
      syntax match vimzipType /\<\h\w*\ze::/ display
    endif
    execute 'syntax match vimzipConstant /\<\u[A-Z0-9_]\+\>/ display' . in
    unlet! b:current_syntax
    execute 'runtime! syntax/' . &syntax . '.vim syntax/' . &syntax . '/*.vim'
  endif
endfunction
augroup vimzip_code
  autocmd!
  autocmd Syntax * call s:CodeSyntax()
augroup END

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
" and none for git's views of a file (fugitive://..., the history window "repo --follow -- x.c"):
" named like C files, they started a language server and were gone before it answered, an error
" (E680) when a git key was pressed right after vim started
let g:ale_pattern_options = {'^/usr/': {'ale_enabled': 0}, '^\a\+://': {'ale_enabled': 0},
      \ ' -- ': {'ale_enabled': 0}}
autocmd BufReadPost /usr/* setlocal readonly nomodifiable

" CMake projects: their include paths and defines come from CMake. A project that does not keep a
" compile_commands.json of its own (cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON) gets one in
" the cache, made in the background the first time one of its C/C++ files opens, and again after a
" CMakeLists.txt is saved; the checks (ALE's cc) and clangd then find its headers, as VSCode's
" CMake Tools does. Other projects without one get their folders with headers as include paths.
" g:vimzip_cmake = 0 turns both off.
let s:cmake = {}
" the build folder vimzip makes for a project: named by the folder and a hash of its path, without
" the % the other cache files use for /, which ALE reads in a command (%s the file, %e, %t): clangd
" was given a path with the file's name in it and found no headers, in any project under a folder
" starting with s, e or t (src/, tools/...)
function! s:CMakeDir(root) abort
  return s:cache . '/cmake/' . substitute(fnamemodify(a:root, ':t'), '[^A-Za-z0-9._-]', '_', 'g') . '-' . sha256(a:root)[: 11]
endfunction
let s:cmake_later = []  " (files opened while vim starts: looked at once it has, see s:Started)
function! s:CMakeRoot(file) abort
  " the topmost folder with a CMakeLists.txt, up to the git work tree's root
  let dir = fnamemodify(a:file, ':p:h')
  let git = finddir('.git', dir . ';')
  let git = git !=# '' ? git : findfile('.git', dir . ';')
  let stop = git !=# '' ? fnamemodify(git, ':p:h:h') : '/'
  let found = ''
  while 1
    if filereadable(dir . '/CMakeLists.txt')
      let found = dir
    endif
    if dir ==# stop || dir ==# fnamemodify(dir, ':h')
      return found
    endif
    let dir = fnamemodify(dir, ':h')
  endwhile
endfunction
function! s:CMake(buf) abort
  let file = fnamemodify(bufname(a:buf), ':p')
  if !get(g:, 'vimzip_cmake', 1) || getbufvar(a:buf, '&buftype') !=# '' || file =~# '^/usr/'
    return
  endif
  " (a project with a compile_commands.json of its own needs neither; one vimzip made is not its own)
  if empty(getbufvar(a:buf, 'ale_c_build_dir_names')) && exists('g:loaded_ale')
        \ && !empty(ale#c#FindCompileCommands(a:buf)[1])
    return
  endif
  let root = executable('cmake') ? s:CMakeRoot(file) : ''
  if root ==# ''
    " no CMake: a project without a compile_commands.json gets its folders with headers as include
    " paths (clangd found none at all, ALE's checks only an include/ at the root)
    let git = finddir('.git', fnamemodify(file, ':h') . ';')
    let git = git !=# '' ? git : findfile('.git', fnamemodify(file, ':h') . ';')
    let root = git !=# '' ? fnamemodify(git, ':p:h:h') : stridx(file, getcwd() . '/') == 0 ? getcwd() : ''
    if root ==# '' || root ==# expand('~')
      return
    endif
    let dir = s:CMakeDir(root)
    if filereadable(dir . '/compile_commands.json')
      call s:CMakeUse(a:buf, dir)
    endif
    if !has_key(s:cmake, root)  " (made again once a session: new folders)
      let s:cmake[root] = {'job': s:GuessJob(root, dir)}
    endif
    return
  endif
  let dir = s:CMakeDir(root)
  if filereadable(dir . '/compile_commands.json')
    call s:CMakeUse(a:buf, dir)
  endif
  if !filereadable(dir . '/compile_commands.json') || getftime(root . '/CMakeLists.txt') > getftime(dir . '/compile_commands.json')
    call s:CMakeConfigure(root, dir)
  endif
endfunction
function! s:CMakeUse(buf, dir) abort
  " (the project's own compile_commands.json, if it has one, still comes first)
  if exists('g:loaded_ale') && empty(getbufvar(a:buf, 'ale_c_build_dir_names'))
        \ && !empty(ale#c#FindCompileCommands(a:buf)[1])
    return
  endif
  call setbufvar(a:buf, 'ale_c_build_dir_names', [a:dir])
endfunction
" CMake 4 stopped configuring projects that ask for a CMake older than 3.5
" (cmake_minimum_required(VERSION 2.8), common in older projects and their bundled libraries):
" "Compatibility with CMake < 3.5 has been removed from CMake". VSCode's CMake Tools gave the same
" error. vimzip's CMake runs and builds set CMAKE_POLICY_VERSION_MINIMUM=3.5, which CMake 4 reads
" to configure them anyway, with 3.5's behaviour (earlier CMake ignores it). One set in the shell
" is kept.
function! s:CMakeEnv() abort
  return $CMAKE_POLICY_VERSION_MINIMUM ==# '' ? {'CMAKE_POLICY_VERSION_MINIMUM': '3.5'} : {}
endfunction
function! s:CMakeConfigure(root, dir) abort
  if job_status(get(get(s:cmake, a:root, {}), 'job', test_null_job())) ==# 'run'
    return
  endif
  call mkdir(a:dir, 'p')
  let log = a:dir . '/vimzip-cmake.log'
  let cmd = (s:lite ? ['nice', '-n', '10'] : []) + ['cmake', '-S', a:root, '-B', a:dir,
        \ '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON', '-Wno-dev']
  let s:cmake[a:root] = {'job': job_start(cmd, {'in_io': 'null', 'out_io': 'file', 'out_name': log,
        \ 'err_io': 'out', 'env': s:CMakeEnv(), 'exit_cb': {_, status -> s:CMakeDone(a:root, a:dir, status)}})}
endfunction
function! s:CMakeDone(root, dir, status) abort
  let made = a:status == 0 && filereadable(a:dir . '/compile_commands.json')
  if !made
    " (a package it needs is missing, ...): the project's folders with headers instead, as VSCode
    " does without one (${workspaceFolder}/**); :CMake tries again
    let guessed = s:GuessIncludes(a:root, a:dir)
    " (in full in :messages; on the screen cut to its width: this comes while typing, and a longer
    " line stopped it at "Press ENTER")
    let msg = 'CMake could not configure ' . fnamemodify(a:root, ':~') . (guessed ? ' (include paths guessed)' : '')
          \ . ': see ' . fnamemodify(a:dir, ':~') . '/vimzip-cmake.log, :CMake to retry'
    silent echomsg msg
    call s:Say(msg, 'WarningMsg')
    if !guessed
      return
    endif
  endif
  call s:HeaderEntries(a:root, a:dir . '/compile_commands.json')
  let again = []
  for b in getbufinfo({'bufloaded': 1})
    if getbufvar(b.bufnr, '&filetype') =~# '^\(c\|cpp\|objc\|objcpp\|cuda\)$' && stridx(b.name, a:root . '/') == 0
      call s:CMakeUse(b.bufnr, a:dir)
      call add(again, b.bufnr)
    endif
  endfor
  " a clangd started before this has the old flags: it starts again with the new ones
  silent! ALEStopLSP clangd
  for b in again
    silent! call ale#Queue(0, 'lint_file', b)
  endfor
endfunction
" a compile_commands.json with the folders that hold headers (and their parents, for "lib/x.h")
" as include paths, one entry per source folder (clangd and ALE use it for the folder's other files)
function! s:GuessJob(root, dir) abort
  let files = []
  return job_start(['rg', '--files', '-t', 'c', '-t', 'cpp', '-t', 'h', a:root], {'in_io': 'null', 'err_io': 'null',
        \ 'out_cb': {_, l -> add(files, l)}, 'close_cb': {_ -> s:GuessIncludes(a:root, a:dir, files) ? s:CMakeDone(a:root, a:dir, 0) : 0}})
endfunction
function! s:GuessIncludes(root, dir, ...) abort
  let files = a:0 ? a:1 : systemlist('rg --files -t c -t cpp -t h ' . shellescape(a:root))
  let hdr = '\.\(h\|hh\|hpp\|hxx\|inl\)$'
  let incs = {}
  for f in filter(copy(files), 'v:val =~? hdr')
    let d = fnamemodify(f, ':h')
    let incs[d] = 1
    if stridx(fnamemodify(d, ':h'), a:root) == 0
      let incs[fnamemodify(d, ':h')] = 1
    endif
    if len(incs) > 300  " (too many to guess from)
      return 0
    endif
  endfor
  let dirs = {}
  for f in filter(files, 'v:val !~? hdr')
    let dirs[fnamemodify(f, ':h')] = f
  endfor
  if empty(dirs) || len(dirs) > 2000
    return 0
  endif
  call mkdir(a:dir, 'p')
  let flags = map(sort(keys(incs)), '"-I" . v:val')
  let db = map(values(dirs), {_, f -> {'directory': a:root, 'file': f,
        \ 'arguments': [f =~? '\.c$' ? 'cc' : 'c++'] + flags + ['-c', f]}})
  call writefile([json_encode(db)], a:dir . '/compile_commands.json')
  return 1
endfunction
" a header opened in a folder without sources (include/uv.h) has no entry to take its flags from:
" each such folder gets the flags of the nearest source (ALE's checks; clangd guesses by itself)
function! s:HeaderEntries(root, json) abort
  if getfsize(a:json) <= 0 || getfsize(a:json) > 8000000
    return
  endif
  try
    let db = json_decode(join(readfile(a:json), ''))
  catch
    return
  endtry
  " (from sources in the project's main language: a C++ header copying a C test's flags was C)
  let cxx = '\.\(cc\|cpp\|cxx\|c++\|C\|mm\)$'
  let lang = len(filter(copy(db), 'v:val.file =~# cxx')) * 2 > len(db) ? cxx : '\.\(c\|m\)$'
  let have = {}
  for e in db
    let have[fnamemodify(e.file =~# '^/' ? e.file : e.directory . '/' . e.file, ':h')] = e
  endfor
  let from = filter(copy(have), 'v:val.file =~# lang')
  let from = empty(from) ? have : from
  let dirs = uniq(sort(map(systemlist('rg --files -g "*.{h,hh,hpp,hxx,inl}" ' . shellescape(a:root)), 'fnamemodify(v:val, ":h")')))
  " the nearest source folder: one under the deepest folder the two share (not a test's, if one as
  " near is not), found by walking up (comparing every pair took a minute on 1,500 folders)
  let test = '/tests\=\(/\|$\)'
  let near = {}
  for [sd, e] in items(from)
    let [p, t] = [sd, sd =~# test]
    while 1
      let cur = get(near, p, {})
      if !empty(cur) && (!cur.test || t)
        break
      endif
      let near[p] = {'e': e, 'test': t}
      let up = fnamemodify(p, ':h')
      if up ==# p
        break
      endif
      let p = up
    endwhile
  endfor
  let added = 0
  for d in filter(dirs, '!has_key(have, v:val)')[: 1999]
    let p = d
    while !has_key(near, p) && fnamemodify(p, ':h') !=# p
      let p = fnamemodify(p, ':h')
    endwhile
    let best = get(near, p, {'e': {}}).e
    if empty(best)
      break
    endif
    let e = deepcopy(best)
    let file = d . '/vimzip-headers.' . fnamemodify(best.file, ':e')
    if has_key(e, 'arguments')
      call map(e.arguments, 'v:val ==# best.file ? file : v:val')
    elseif has_key(e, 'command')
      let e.command = substitute(e.command, '\V' . escape(best.file, '\'), escape(file, '&\'), 'g')
    endif
    let e.file = file
    call add(db, e)
    let added += 1
  endfor
  if added
    call writefile([json_encode(db)], a:json)
  endif
endfunction
" (again for a project vimzip configured, not one with a compile_commands.json of its own)
function! s:CMakeSaved(file) abort
  let root = s:CMakeRoot(a:file)
  let dir = s:CMakeDir(root)
  if root !=# '' && get(g:, 'vimzip_cmake', 1) && filereadable(dir . '/CMakeCache.txt')
    call s:CMakeConfigure(root, dir)
  endif
endfunction
function! s:CMakeHere() abort
  let root = s:CMakeRoot(expand('%:p'))
  if root ==# ''
    echo 'No CMakeLists.txt above this file'
    return
  endif
  call s:CMakeConfigure(root, s:CMakeDir(root))
  call s:Say('CMake: configuring ' . fnamemodify(root, ':~') . ' for its include paths...')
endfunction
command! -bar CMake call s:CMakeHere()
" a .h with no C++ in its first lines is C to vim; in a project of mostly C++ sources it is C++
" (fmt's format.h: checked as C, "'type_traits' file not found")
let s:cpp_project = {}
function! s:CppHeader() abort
  let file = expand('<afile>:p')
  " (not system headers: those stay as vim tells)
  if expand('<afile>:e') !=# 'h' || &buftype !=# '' || file =~# '^/usr/'
    return
  endif
  let git = finddir('.git', fnamemodify(file, ':h') . ';')
  let root = git !=# '' ? fnamemodify(git, ':p:h:h') : fnamemodify(file, ':h')
  if !has_key(s:cpp_project, root)
    let n = {}
    for ext in ['c', 'cpp']
      let n[ext] = len(systemlist('rg --files -t ' . ext . ' -g "!*.h" ' . shellescape(root) . ' | head -n 5000'))
    endfor
    let s:cpp_project[root] = n.cpp > n.c
  endif
  if s:cpp_project[root]
    setlocal filetype=cpp
  endif
endfunction
augroup vimzip_cmake
  autocmd!
  autocmd FileType c call s:CppHeader()
  autocmd FileType c,cpp,objc,objcpp,cuda if get(s:, 'bar_on', 0) | call s:CMake(str2nr(expand('<abuf>')))
        \ | else | call add(s:cmake_later, str2nr(expand('<abuf>'))) | endif
  autocmd BufWritePost CMakeLists.txt,*.cmake call s:CMakeSaved(expand('<afile>:p'))
augroup END

" tags for the system headers the current C/C++ file includes (via cc -M)
function! s:SysTags() abort
  let cxx = &filetype ==# 'cpp'
  let cc = get(filter(cxx ? ['c++', 'g++', 'clang++'] : ['cc', 'gcc', 'clang'], 'executable(v:val)'), 0, '')
  if cc ==# '' | return 0 | endif
  let src = expand('%:p')
  let dirs = uniq(sort([expand('%:p:h'), expand('%:p:h:h') . '/include', getcwd(), getcwd() . '/include']))
  " the build's own flags (compile_commands.json from CMake etc.) via ALE, then guessed dirs
  let flags = exists('g:loaded_ale') ? ale#c#GetCFlags(bufnr(''), []) : ''
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
  " (the folders the build gives this file, CMake's included: headers deeper in the project)
  let args = exists('g:loaded_ale') ? split(ale#c#GetCFlags(bufnr(''), [])) : []
  let flags = []
  for i in range(len(args))
    let d = matchstr(args[i], '^-\%(I\|isystem\|iquote\)\zs.*')
    let d = d ==# '' && args[i] =~# '^-\%(I\|isystem\|iquote\)$' ? get(args, i + 1, '') : d
    if d !=# ''
      call add(flags, substitute(d, '^[''"]\(.*\)[''"]$', '\1', ''))
    endif
  endfor
  let dirs = [expand('%:p:h')] + flags + [expand('%:p:h:h') . '/include', getcwd(), getcwd() . '/include']
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
  \                                  ['pylsp', 'pylsp', 'pipx install python-lsp-server']]],
  \ ['go', 'Go', ['go'], [['gopls', 'gopls', 'go install golang.org/x/tools/gopls@latest']]],
  \ ['dart', 'Dart/Flutter', ['dart'], [['analysis_server', 'dart', 'install the Dart or Flutter SDK']]],
  \ ['typescript', 'TypeScript/JS', ['typescript', 'javascript', 'typescriptreact', 'javascriptreact'],
  \   [['tsserver', 'tsserver', 'npm install -g typescript']]],
  \ ['lua', 'Lua', ['lua'], [['lua_language_server', 'lua-language-server', 'install lua-language-server']]],
  \ ['bash', 'Bash', ['sh'], [['language_server', 'bash-language-server', 'npm install -g bash-language-server']]],
  \ ['zig', 'Zig', ['zig'], [['zls', 'zls', 'install zls']]],
  \ ['cmake', 'CMake', ['cmake'], [['cmake_language_server', 'cmake-language-server', "pipx install cmake-language-server; pipx inject cmake-language-server 'pygls<2'"]]]]
" (ALE has no CMake server of its own: commands' help on K, completion, in CMakeLists.txt; it reads
" the targets from the build vimzip made for the project, see "CMake projects")
function! s:CMakeLspRoot(buffer) abort
  let root = s:CMakeRoot(fnamemodify(bufname(a:buffer), ':p'))
  return root !=# '' ? root : fnamemodify(bufname(a:buffer), ':p:h')
endfunction
" (the project's own build, if it keeps one with a compile_commands.json)
function! s:CMakeBuildDir(buffer) abort
  let own = exists('g:loaded_ale') ? ale#c#FindCompileCommands(a:buffer)[1] : ''
  return own !=# '' ? fnamemodify(own, ':h') : s:CMakeDir(s:CMakeLspRoot(a:buffer))
endfunction
" (made known to ALE when a CMake file first opens: at start, loading ALE's linter code took 1.4 ms)
function! s:CMakeLsp() abort
  silent! call ale#linter#Define('cmake', {'name': 'cmake_language_server', 'lsp': 'stdio',
        \ 'executable': 'cmake-language-server', 'command': '%e',
        \ 'project_root': function('s:CMakeLspRoot'),
        \ 'initialization_options': {b -> {'buildDirectory': s:CMakeBuildDir(b)}}})
endfunction
augroup vimzip_cmake_lsp
  autocmd!
  autocmd FileType cmake ++once call s:CMakeLsp()
augroup END
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
let s:lsp_done = {}
function! s:LspSetup() abort
  let s:lsp_on = {}
  for lang in s:servers
    let [state, _, linter] = s:LspState(lang)
    for ft in lang[2]
      let s:lsp_done[ft] = 1
      let g:ale_linters[ft] = state ==# 'on' ? [linter] + get(s:also, ft, []) : get(s:checkers, ft, [])
      if state ==# 'on'
        let s:lsp_on[ft] = linter
      endif
    endfor
  endfor
endfunction
" (one language at a time, the first time a file of it opens: all of them at start, each looked
" up on PATH, took 2 ms)
function! s:LspFor(ft) abort
  if has_key(s:lsp_done, a:ft)
    return
  endif
  let s:lsp_done[a:ft] = 1
  for lang in filter(copy(s:servers), 'index(v:val[2], a:ft) >= 0')
    let [state, _, linter] = s:LspState(lang)
    for ft in lang[2]
      let s:lsp_done[ft] = 1
      let g:ale_linters[ft] = state ==# 'on' ? [linter] + get(s:also, ft, []) : get(s:checkers, ft, [])
      if state ==# 'on'
        let s:lsp_on[ft] = linter
      else
        silent! call remove(s:lsp_on, ft)
      endif
    endfor
  endfor
endfunction
function! s:LspHere() abort
  call s:LspFor(&filetype)
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
  autocmd FileType * call s:LspFor(&filetype) | call s:LspOmni(bufnr(''))
  " (ALE tells a buffer its server started when it is entered again, not quietly: a server that
  " started while the tree or a list was in front printed "No matching autocommands")
  autocmd User ALELSPStarted :
augroup END
" :Lsp {language} [on|off]: switch a server (no argument: the list); its open files are checked again
function! s:LspSet(id, ...) abort
  let lang = get(filter(copy(s:servers), 'v:val[0] ==# a:id'), 0, [])
  if empty(lang)
    call s:Say('Unknown language: ' . a:id . ' (' . join(map(copy(s:servers), 'v:val[0]'), ', ') . ')', 'WarningMsg')
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
  let s:blame_gen = get(s:, 'blame_gen', 0) + 1
  let gen = s:blame_gen
  let s:blame_job = job_start(['git', '-C', expand('%:p:h'), 'blame', '--porcelain', '-L', lnum . ',' . lnum, '--', expand('%:t')],
        \ {'err_io': 'null', 'out_cb': {_, l -> add(out, l)}, 'close_cb': {_ -> s:BlameShow(buf, lnum, out, gen)}})
endfunction
function! s:BlameShow(buf, lnum, out, gen) abort
  " (only the latest request: a stopped one still reports, and the line got its text twice)
  if empty(a:out) || a:gen != s:blame_gen || bufnr('') != a:buf || line('.') != a:lnum || mode() !=# 'n'
        \ || &modified || exists('s:blame_at')
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
  let s:tl.want = f
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
  " (an older file's history arriving last, after Tab moved on to another, is not shown)
  if !bufexists(s:tl.buf) || a:file !=# get(s:tl, 'want', a:file)
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
    " (the Markdown preview and the replace list belong to the file, as panels do)
    if index(['nerdtree', 'tagbar', 'vimziptimeline', 'vimzipmdpreview', 'vimzipreplace'], getbufvar(b, '&filetype')) < 0
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
" the same keys as in the tree, the problems and a peeked definition: Enter opens, Ctrl+v beside,
" Ctrl+x below (Ctrl+t's vim tab page left out: vimzip's tabs are the files)
let g:fzf_action = {'ctrl-v': 'vsplit', 'ctrl-x': 'split'}
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
  if exists('*nerdtree#echo') && !exists('s:nerdtree_echo')
    let s:nerdtree_echo = 1
    " (it redrew the whole screen to clear the command line after reading each folder: 4 ms as vim
    " started, and a flash at each folder opened)
    function! nerdtree#echo(msg) abort
      if a:msg ==# ''
        echo ''
      else
        redraw
        echomsg 'NERDTree: ' . a:msg
      endif
    endfunction
  endif
  if exists('g:NERDTreeDirNode') && exists('g:NERDTreeFileNode') && !exists('s:nerdtree_sort')
    let s:nerdtree_sort = g:NERDTreeDirNode.sortChildren
    let g:NERDTreeDirNode.sortChildren = function('s:NERDTreeSortChildren')
    let g:NERDTreeDirNode._renderToString = function('s:NERDTreeRender')
    let g:NERDTreeFileNode._renderToString = function('s:NERDTreeRender')
  endif
  " the git colors arriving while typing wait for the typing to stop: putting them in went to the
  " tree's window and back, which put the cursor one letter back or ended insert mode (a save
  " just before, Ctrl+s or the autosave on Esc, then typing again at once)
  if exists('g:NERDTreePathNotifier') && !exists('s:tree_git_ui')
    for L in g:NERDTreePathNotifier.GetListenersForEvent('init')
      " (get() with a default gives the default here, not the partial's dictionary)
      let d = type(L) == v:t_func ? get(L, 'dict') : {}
      if type(d) == v:t_dict && has_key(d, 'TryUpdateNERDTreeUI')
        let s:tree_git_ui = d.TryUpdateNERDTreeUI
        let d.TryUpdateNERDTreeUI = function('s:TreeGitUI')
      endif
    endfor
  endif
  if exists('g:NERDTreeMenuItem')
    let ours = {'NERDTreeAddNode': 'VimzipTreeAdd', 'NERDTreeMoveNode': 'VimzipTreeMove', 'NERDTreeCopyNode': 'VimzipTreeCopy'}
    for item in g:NERDTreeMenuItem.All()
      if type(get(item, 'callback', 0)) == v:t_string && has_key(ours, item.callback)
        let item.callback = ours[item.callback]
      endif
    endfor
  endif
endfunction
function! s:TreeGitUI() dict abort
  if mode() !=# 'n'
    let s:tree_git_wait = self
    augroup vimzip_tree_git_later
      autocmd!
      autocmd InsertLeave * ++once call timer_start(0, {-> s:tree_git_wait.TryUpdateNERDTreeUI()})
    augroup END
    return
  endif
  call call(s:tree_git_ui, [], self)
endfunction
" the tree's m menu (add, move / rename, copy): a path typed without its folder is taken in the
" selected node's folder (calc2.c: renamed where it is, new.c: created in the selected folder), not
" from the project's root; for a move that was broken input, leaving the tab on the old name
function! s:TreeMenu(node, prompt, default, Then) abort
  let new = trim(input(a:prompt, a:default, 'file'))
  if new ==# '' || new ==# a:default
    return
  endif
  let base = a:node.path.isDirectory && a:Then is# function('NERDTreeAddNode') ? a:node.path.str()
        \ : fnamemodify(a:node.path.str(), ':h')
  let dir = new =~# '/$'
  let new = simplify(fnamemodify(expand(new =~# '^[/~]' ? new : base . '/' . new), ':p'))
  let new = substitute(new, '/$', '', '') . (dir ? '/' : '')
  " NERDTree's own action, its path question answered with the full path
  call feedkeys("\<C-u>" . new . "\<CR>", 'ni')
  call a:Then()
endfunction
function! VimzipTreeAdd() abort
  let node = g:NERDTreeDirNode.GetSelected()
  if !empty(node)
    call s:TreeMenu(node, 'New file (a folder: end with /): ', node.path.str() . '/', function('NERDTreeAddNode'))
  endif
endfunction
function! VimzipTreeMove() abort
  let node = g:NERDTreeFileNode.GetSelected()
  if !empty(node)
    call s:TreeMenu(node, 'Rename or move to: ', node.path.str(), function('NERDTreeMoveNode'))
  endif
endfunction
function! VimzipTreeCopy() abort
  let node = g:NERDTreeFileNode.GetSelected()
  if !empty(node)
    call s:TreeMenu(node, 'Copy to: ', node.path.str(), function('NERDTreeCopyNode'))
  endif
endfunction

" termdebug, loaded when first used (at start it took 2.7 ms)
let g:termdebug_config = {'wide': 1}
function! s:TermdebugLoad(cmd) abort
  silent! delcommand Termdebug
  silent! delcommand TermdebugCommand
  packadd termdebug
  execute a:cmd
endfunction
" (its commands, standing in until then, are made after ~/.config/vimzip/vimrc is read: one that
" loads termdebug itself got E174 "Command already exists")

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
  " a sticky line over a window's top: to that line (as VSCode)
  let sticky = get(get(s:, 'sticky_at', {}), m.winid, [])
  if !empty(sticky)
    let lnum = get(sticky[1], m.winrow - 1, sticky[1][-1])
    return ":\<C-u>call win_gotoid(" . sticky[0] . ")|call cursor(" . lnum . ", 1)|normal! ^zt\<CR>"
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
  let w = getmousepos().winid
  return has_key(get(s:, 'ruler_info', {}), w) || has_key(get(s:, 'sticky_at', {}), w) ? "\<Esc>" . s:Click() : "\<LeftMouse>"
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
  \ 'cs': 'C#', 'php': 'PHP', 'typescriptreact': 'TypeScript JSX', 'javascriptreact': 'JavaScript JSX',
  \ 'objc': 'Objective-C', 'objcpp': 'Objective-C++', 'cuda': 'CUDA C++', 'toml': 'TOML', 'scss': 'SCSS',
  \ 'dosini': 'Ini', 'tex': 'LaTeX', 'gitconfig': 'Git Config', 'jsonc': 'JSON with Comments',
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
        \ : b == get(s:, 'build', -1) ? 'BUILD' : getbufvar(b, '&buftype') ==# 'terminal' ? 'TERMINAL'
        \ : getbufvar(b, '&buftype') ==# 'quickfix' ? (get(getwininfo(a:w)[0], 'loclist') ? 'LOCATION LIST'
        \   : get(getqflist({'context': 0}), 'context', '') is# 'vimzip_problems' ? 'PROBLEMS' : 'QUICKFIX')
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
      let click = !has('statusline_click') ? '' : group ==# 'VimzipBarProblems' ? '%[VimzipProblemsClick]'
            \ : group ==# 'VimzipBarBranch' ? '%[VimzipBranchClick]' : ''
      let unclick = click !=# '' ? '%[]' : ''
      let out .= repeat(' ', start - pos) . click . '%#' . group . '#' . s:Esc(join(part, '')) . '%#VimzipBar#' . unclick
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
" the branch, read from git's HEAD file (kept until it changes): FugitiveHead() loads all of
" fugitive (7 ms at start) and took 0.7 ms for each of the status line's many redraws
let s:heads = {}
function! s:Head(b) abort
  let dir = exists('*FugitiveActualDir') ? FugitiveActualDir(a:b) : ''
  if dir ==# ''
    return ''
  endif
  let f = dir . '/HEAD'
  if !filereadable(f)
    return ''
  endif
  let stamp = [getftime(f), getfsize(f)]
  let known = get(s:heads, dir, [[], ''])
  if known[0] ==# stamp
    return known[1]
  endif
  let line = get(readfile(f, '', 1), 0, '')
  " (a detached HEAD: its commit, short, as VSCode shows)
  let head = line =~# '^ref: refs/heads/' ? line[16 :] : line =~# '^ref: ' ? line[5 :] : line[: 6]
  let s:heads[dir] = [stamp, head]
  return head
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
  for item in [s:Head(b), VimzipProblems(b)]
    if item !=# ''
      " (clicked: the branch switches branch, E / W opens the problems)
      call add(placed, [x, s:BarCells(x, item, joins), item =~# '^E \d' ? 'VimzipBarProblems' : 'VimzipBarBranch'])
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
  " (while vim starts, the session and the tree opening asked 7 times: once, when it has started)
  if !get(s:, 'bar_on', 0)
    return
  endif
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
" the place on this line of a list (problems, search results) beside or below the editor
function! s:QfOpen(how) abort
  let loc = getwininfo(win_getid())[0].loclist
  let items = loc ? getloclist(0) : getqflist()
  let it = get(items, line('.') - 1, {})
  if !get(it, 'bufnr', 0)
    return
  endif
  if !loc
    call setqflist([], 'a', {'idx': line('.')})
  endif
  call s:EditWin()
  execute a:how
  execute 'buffer' it.bufnr
  call cursor(it.lnum, max([1, it.col]))
  normal! zz
endfunction
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
  call s:BufClose(bufnr(''), '')
endfunction
" why a tab cannot close: changes that were not saved, and how to save or drop them
function! s:NotSaved(b) abort
  let name = bufname(a:b)
  if name ==# ''
    call s:Say('No write since last change (Ctrl+s to save, :q! to discard)', 'ErrorMsg')
  elseif getbufvar(a:b, '&readonly') || !filewritable(name) && filereadable(name)
    call s:Say(fnamemodify(name, ':t') . ' is read-only: changes not saved (:w! to save anyway, :q! to discard)', 'ErrorMsg')
  else
    call s:Say(fnamemodify(name, ':t') . ': changes not saved (:w to retry, :q! to discard)', 'ErrorMsg')
  endif
endfunction
" close a tab (buffer): every window showing it shows another tab first, or one empty tab, since
" :bdelete closes those windows (the same file open in two splits lost one of them)
function! s:BufClose(b, bang) abort
  if a:bang ==# '' && getbufvar(a:b, '&modified')
    " (one that cannot be saved: no name, read-only; :bdelete refused it silently, its tab stayed)
    call s:NotSaved(a:b)
    return
  endif
  let blank = -1
  for w in win_findbuf(a:b)
    if len(getbufinfo({'buflisted': 1})) > 1
      call win_execute(w, 'bprevious')
    elseif blank < 0
      call win_execute(w, 'enew')
      let blank = winbufnr(w)
    else
      call win_execute(w, 'buffer ' . blank)
    endif
  endfor
  execute 'silent! bdelete' . a:bang a:b
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
    " an unsaved buffer (named ones are saved automatically, unless read-only): closing its only
    " window would leave vim with just the panels
    call s:NotSaved(bufnr(''))
    return
  endif
  if &buftype ==# '' && a:bang
    setlocal nomodified  " discard: keep autosave (on leaving the buffer) from writing it
  endif
  if &buftype ==# '' && editwins < 2 && tabpagenr('$') > 1
    " the last file of one of vim's tab pages (:tabnew): that tab page closes (and an empty
    " buffer it had leaves no empty tab behind)
    let bufs = tabpagebuflist()
    execute 'tabclose' . (a:bang ? '!' : '')
    for b in bufs
      if bufname(b) ==# '' && getbufvar(b, '&buftype') ==# '' && !getbufvar(b, '&modified') && empty(win_findbuf(b))
        execute 'silent! bwipeout' b
      endif
    endfor
    return
  endif
  if &buftype !=# '' || editwins > 1 || len(getbufinfo({'buflisted': 1})) < 2
    let s:quitting = &buftype ==# '' && editwins < 2  " the last file: leave vim
    execute 'quit' . (a:bang ? '!' : '')
    return
  endif
  call s:BufClose(bufnr(''), a:bang ? '!' : '')
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
        \ : b == get(s:, 'ai', -1) ? 'ai'
        \ : index([get(s:, 'term', -1), get(s:, 'build', -1), get(s:, 'git_panel', -1)], b) >= 0 ? 'term' : ''
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
      " (the bottom terminal under everything goes back there when the tree returns)
      let t = bufwinid(get(s:, 'term', -1))
      let s:term_full = t > 0 && winwidth(t) == &columns
      NERDTreeClose
      let s:tree_hidden = 1
    endif
  elseif get(s:, 'tree_hidden', 0) && want.fits
    let s:tree_hidden = 0
    NERDTreeToggle
    let t = bufwinid(get(s:, 'term', -1))
    if get(s:, 'term_full', 0) && t > 0
      call win_execute(t, 'wincmd J')
    endif
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
  " (a file saved while typing, Ctrl+s: going to the tree and back ended insert mode, and the next
  " letters typed ran as commands; shown once the typing stops)
  if mode() !=# 'n'
    augroup vimzip_reveal_later
      autocmd!
      autocmd InsertLeave * ++once call timer_start(0, {-> s:RevealInTree()})
    augroup END
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
      \ . ' -t dart -t zig -t kotlin -t swift -t ruby -t php -t csharp -t scala -t elixir -t haskell -t perl'
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
  " Ctrl+s from habit saves the files: the shell took it as "pause the output" (XOFF), and the
  " terminal looked frozen until Ctrl+q
  tnoremap <buffer> <silent> <C-s> <C-w>:call <SID>TermSave()<CR>
endfunction
function! s:TermSave() abort
  let n = len(getbufinfo({'bufmodified': 1, 'buflisted': 1}))
  silent! wall
  call s:Say(n ? 'Saved ' . s:Count(n, 'file') : 'All files are saved')
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
    " (lightline worked out its colors again after a session loaded: 7 ms, for colors that had not
    " changed)
    silent! autocmd! lightline SessionLoadPost
    " (and tagbar loaded all of itself, 3 ms, to bring back an outline the session never has)
    silent! autocmd! TagbarSession
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

" (s:SessionSave, not s:Save: Ctrl+s's function took that name and sessions stopped being saved)
function! s:SessionSave() abort
  if !exists('s:session') | return | endif
  " in every tab page (:tabnew): another one's terminal came back as an empty buffer
  let here = tabpagenr()
  for t in range(1, tabpagenr('$'))
    execute 'noautocmd tabnext' t
    silent! NERDTreeClose
    silent! diffoff!
    for w in reverse(range(1, winnr('$')))
      " panels and git's views of a file (diffs, old versions) are not part of the session
      if winnr('$') > 1 && (getwinvar(w, '&buftype') !=# '' || bufname(winbufnr(w)) =~# '^\a\+://')
        execute w . 'close'
      endif
    endfor
  endfor
  execute 'noautocmd tabnext' here
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
  call s:SessionSave()
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

" Space fp: the projects listed in ~/.config/vimzip/projects (added with Ctrl+a, typed or picked in
" a folder tree, or by editing the file with Ctrl+e: one folder per line, in that order), then the
" recent ones (folders with a saved session, newest first). Ctrl+x takes one off the list (out of the file, and hidden from the
" recent ones until it is opened again).
let s:projects_file = expand('~/.config/vimzip/projects')
let s:projects_hidden = s:cache . '/projects-hidden'
function! s:ReadList(file) abort
  return filereadable(a:file) ? map(filter(readfile(a:file), 'v:val !~# "^\\s*\\(#\\|$\\)"'), 'fnamemodify(expand(trim(v:val)), ":p:s?/$??")') : []
endfunction
function! s:WriteList(file, dirs) abort
  call mkdir(fnamemodify(a:file, ':h'), 'p')
  let head = a:file ==# s:projects_file ? ['# vimzip projects (Space fp): one folder per line, listed first in this order'] : []
  call writefile(head + map(copy(a:dirs), 'fnamemodify(v:val, ":~")'), a:file)
endfunction
function! s:RecentProjects() abort
  let listed = s:ReadList(s:projects_file)
  let hidden = s:ReadList(s:projects_hidden)
  let files = glob(s:cache . '/sessions/*.vim', 0, 1)
  call sort(files, {a, b -> getftime(b) - getftime(a)})
  let recent = filter(map(files, {_, f -> s:SessionDir(f)}), {_, d -> index(listed, d) < 0 && index(hidden, d) < 0})
  return map(filter(listed + recent, {_, d -> isdirectory(d) && d !=# getcwd()}), {_, d -> fnamemodify(d, ':~')})
endfunction
function! s:PickProject() abort
  call fzf#run(fzf#wrap({'source': s:RecentProjects(), 'sink*': function('s:PickedProject'),
        \ 'options': ['--prompt', 'Project> ', '--print-query', '--expect', 'ctrl-a,ctrl-d,ctrl-e',
        \   '--header', 'Enter open (or a typed path)   Ctrl+a add (a folder tree)   Ctrl+d remove   Ctrl+e edit the list',
        \   '--bind', 'enter:accept-or-print-query']}))
endfunction
function! s:PickedProject(lines) abort
  let [query, key] = [get(a:lines, 0, ''), get(a:lines, 1, '')]
  let picked = filter(a:lines[2:], 'v:val !=# ""')
  " a typed folder wins over the entry it happens to match ("~/work/ap" picked ~/work/api)
  let typed = fnamemodify(expand(trim(query)), ':p:s?/$??')
  if key ==# 'ctrl-a'
    if query =~# '\S' && isdirectory(typed)
      call s:AddProject(typed)
      call timer_start(0, {-> s:PickProject()})  " the list again, changed
    else
      " the folder picked in a tree, from the typed path's nearest folder, or home
      let start = query =~# '\S' ? typed : expand('~')
      while !isdirectory(start) && fnamemodify(start, ':h') !=# start
        let start = fnamemodify(start, ':h')
      endwhile
      call timer_start(0, {-> s:FolderTree(start)})
    endif
    return
  endif
  if key ==# '' && query =~# '^\s*[~./]' && isdirectory(typed)
    let picked = [query]
  endif
  let dirs = map(empty(picked) ? (query ==# '' ? [] : [query]) : picked, 'fnamemodify(expand(trim(v:val)), ":p:s?/$??")')
  if key ==# 'ctrl-e'
    if !filereadable(s:projects_file)
      call s:WriteList(s:projects_file, [])
    endif
    call s:Buf('edit ' . fnameescape(s:projects_file))
    return
  elseif key ==# 'ctrl-d'
    let listed = s:ReadList(s:projects_file)
    let hidden = s:ReadList(s:projects_hidden)
    for d in dirs
      call filter(listed, 'v:val !=# d')
      call add(hidden, d)
    endfor
    call s:WriteList(s:projects_file, listed)
    call s:WriteList(s:projects_hidden, uniq(sort(hidden)))
    call timer_start(0, {-> s:PickProject()})  " the list again, changed
    return
  endif
  if !empty(dirs)
    " (opened again: no longer hidden)
    let hidden = s:ReadList(s:projects_hidden)
    if index(hidden, dirs[0]) >= 0
      call s:WriteList(s:projects_hidden, filter(hidden, 'v:val !=# dirs[0]'))
    endif
    call s:OpenProject(dirs[0])
  endif
endfunction
function! s:AddProject(dir) abort
  call s:WriteList(s:projects_file, filter(s:ReadList(s:projects_file), 'v:val !=# a:dir') + [a:dir])
  let hidden = s:ReadList(s:projects_hidden)
  if index(hidden, a:dir) >= 0
    call s:WriteList(s:projects_hidden, filter(hidden, 'v:val !=# a:dir'))
  endif
endfunction
" the folder tree of Space fp's Ctrl+a: Enter (l, h) opens and closes a folder, a adds the one at
" the cursor, - goes up from the top folder, . shows hidden folders, Esc goes back to the list
let s:ftree = {}
function! s:FolderTree(start) abort
  let s:ftree = {'root': a:start, 'open': {a:start: 1}, 'hidden': 0, 'rows': []}
  let s:ftree.id = popup_create([], {'title': ' Add a project: Enter open/close  a add  - up  . hidden  Esc back ',
        \ 'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1],
        \ 'cursorline': 1, 'mapping': 0, 'filter': function('s:FolderTreeKey'), 'zindex': 300,
        \ 'minwidth': min([70, &columns - 8]), 'maxwidth': &columns - 8,
        \ 'minheight': min([20, &lines - 8]), 'maxheight': &lines - 8})
  call s:FolderTreeDraw(1)
endfunction
function! s:FolderTreeDirs(dir) abort
  let base = a:dir ==# '/' ? '' : a:dir
  try
    let names = readdir(a:dir, {n -> (s:ftree.hidden || n[0] !=# '.') && isdirectory(base . '/' . n)})
  catch  " (a folder it may not read)
    return []
  endtry
  return map(sort(names, 'i'), 'base . "/" . v:val')
endfunction
function! s:FolderTreeRows(dir, depth, rows) abort
  for d in s:FolderTreeDirs(a:dir)
    call add(a:rows, [d, a:depth])
    if get(s:ftree.open, d) && len(a:rows) < 5000
      call s:FolderTreeRows(d, a:depth + 1, a:rows)
    endif
  endfor
endfunction
function! s:FolderTreeDraw(lnum) abort
  let rows = [[s:ftree.root, 0]]
  call s:FolderTreeRows(s:ftree.root, 1, rows)
  let s:ftree.rows = rows
  let lines = map(copy(rows), {_, r -> repeat('  ', r[1]) . (get(s:ftree.open, r[0]) ? '▾ ' : '▸ ')
        \ . (r[1] ? fnamemodify(r[0], ':t') : substitute(fnamemodify(r[0], ':~'), '/$', '', '')) . '/'})
  call popup_settext(s:ftree.id, lines)
  call win_execute(s:ftree.id, 'call cursor(' . max([1, min([a:lnum, len(rows)])]) . ', 1)')
endfunction
function! s:FolderTreeRow(dir) abort
  return index(map(copy(s:ftree.rows), 'v:val[0]'), a:dir) + 1
endfunction
function! s:FolderTreeKey(id, key) abort
  let n = line('.', a:id)
  let dir = s:ftree.rows[n - 1][0]
  if index(['j', "\<Down>", "\<C-n>", "\<Tab>"], a:key) >= 0
    call win_execute(a:id, 'normal! j')
  elseif index(['k', "\<Up>", "\<C-p>", "\<S-Tab>"], a:key) >= 0
    call win_execute(a:id, 'normal! k')
  elseif index(['G', "\<End>", "\<PageDown>", "\<C-f>", "\<C-d>"], a:key) >= 0
    call win_execute(a:id, 'normal! ' . (a:key ==# 'G' || a:key ==# "\<End>" ? 'G' : '10j'))
  elseif index(['g', "\<Home>", "\<PageUp>", "\<C-b>", "\<C-u>"], a:key) >= 0
    call win_execute(a:id, 'normal! ' . (a:key ==# 'g' || a:key ==# "\<Home>" ? 'gg' : '10k'))
  elseif index(["\<CR>", 'o', 'l', "\<Right>"], a:key) >= 0
    if get(s:ftree.open, dir) && n > 1 && index(["\<CR>", 'o'], a:key) >= 0
      call remove(s:ftree.open, dir)
    else
      let s:ftree.open[dir] = 1
    endif
    call s:FolderTreeDraw(n)
  elseif index(['h', "\<Left>"], a:key) >= 0
    if get(s:ftree.open, dir) && n > 1
      call remove(s:ftree.open, dir)
      call s:FolderTreeDraw(n)
    elseif n > 1
      call win_execute(a:id, 'call cursor(' . s:FolderTreeRow(fnamemodify(dir, ':h')) . ', 1)')
    endif
  elseif index(['-', "\<BS>", 'u'], a:key) >= 0
    let up = fnamemodify(s:ftree.root, ':h')
    if up !=# s:ftree.root
      let s:ftree.open[up] = 1
      let s:ftree.root = up
      call s:FolderTreeDraw(1)
      call s:FolderTreeDraw(s:FolderTreeRow(dir))
    endif
  elseif a:key ==# '.'
    let s:ftree.hidden = !s:ftree.hidden
    call s:FolderTreeDraw(1)
    call s:FolderTreeDraw(max([1, s:FolderTreeRow(dir)]))
  elseif index(['a', ' ', "\<C-a>"], a:key) >= 0
    call popup_close(a:id)
    call s:AddProject(dir)
    call timer_start(0, {-> s:PickProject()})
  elseif index(["\<Esc>", 'q', "\<C-c>"], a:key) >= 0
    call popup_close(a:id)
    call timer_start(0, {-> s:PickProject()})
  endif
  return 1  " (every key is the tree's)
endfunction
command! -nargs=? -complete=dir Project if <q-args> ==# '' | call s:PickProject() | else | call s:OpenProject(<q-args>) | endif

function! s:TermOpen(buf) abort
  call setbufvar(a:buf, '&buflisted', 0)
  " any terminal, also one from :terminal, ends with vim, like vimzip's own (++kill=hup): :qa or
  " :q in the last file stopped at E947 "Job still running", leaving the tree and the terminal
  call term_setkill(a:buf, 'hup')
  if bufnr('') == a:buf
    setlocal nonumber nocursorline signcolumn=no nolist
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
  " (a popup that scrolled, Space fp's list or the help, has no marks to move)
  if win_gettype() !=# '' || empty(s:rulers)
    return
  endif
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
        \      ['backup/*', 7, {f -> 0}],
        \      ['cmake/*', 90, {f -> Hashed(f) || isdirectory(substitute(fnamemodify(f, ':t'), '%', '/', 'g'))}]]
  for [pat, days, Exists] in rules
    for f in glob(s:cache . '/' . pat, 1, 1)
      let age = (localtime() - getftime(f)) / day
      if age > days || (age > min([days, 30]) && !Exists(f))
        call delete(f, isdirectory(f) ? 'rf' : '')
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

" :e on a folder: that folder opened in the tree, not an empty tab named after it (whose autosave
" then failed: "is a directory")
function! s:OpenDir(buf) abort
  if !bufexists(a:buf) || !isdirectory(bufname(a:buf))
    return
  endif
  let dir = substitute(fnamemodify(bufname(a:buf), ':p'), '.\zs/$', '', '')
  call s:BufClose(a:buf, '')
  execute 'silent! bwipeout' a:buf
  " under the project's root: shown open there; outside it: as the tree's root
  if dir ==# getcwd()
    NERDTreeFocus
  elseif stridx(dir, getcwd() . '/') == 0
    execute 'NERDTreeFind' fnameescape(dir . '/')
  else
    execute 'NERDTree' fnameescape(dir)
  endif
endfunction

augroup vimzip
  autocmd!
  autocmd BufEnter * if v:vim_did_enter && &buftype ==# '' && isdirectory(expand('<afile>'))
        \ | let s:dirbuf = str2nr(expand('<abuf>')) | call timer_start(0, {-> s:OpenDir(s:dirbuf)}) | endif
  autocmd BufEnter * let s:enter = [win_getid(), bufnr('')] | call timer_start(0, {-> s:KeepPanel(s:enter[0], s:enter[1])})
  autocmd VimEnter * call timer_start(5000, function('s:Prune'))
  autocmd VimEnter * call s:FastNERDTree()
  autocmd VimEnter * ++nested call s:Start()
  autocmd VimEnter * let s:bar_on = 1 | call s:BarRefresh()
  autocmd VimEnter * call timer_start(0, {-> s:Started()})
  autocmd VimEnter * call timer_start(0, {-> s:GitGutterOn()})
  autocmd VimEnter,BufWritePost * if !s:lite | call s:Words() | endif
  autocmd VimLeavePre * call s:SessionSave()
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
  autocmd FileType qf nnoremap <buffer> <silent> <C-v> :call <SID>QfOpen('vsplit')<CR>
        \| nnoremap <buffer> <silent> <C-x> :call <SID>QfOpen('split')<CR>
        \| nnoremap <buffer> <silent> q :close<CR>
  " the timeline lives under the tree: it goes away and comes back with it
  autocmd BufWinLeave NERD_tree_* call timer_start(0, {-> s:TreeGone()})
  autocmd BufWinEnter NERD_tree_* call timer_start(0, {-> s:TreeBack()})
  " a timeline comparison left by opening another file in one of its windows (Tab, the tree, Ctrl+p)
  autocmd BufWinEnter * if get(s:tl, 'viewing', 0) && get(w:, 'vimzip_tl', 0) && bufname('') !~# '^fugitive://'
        \ && bufnr('') != bufnr(s:tl.file) | call timer_start(0, {-> s:TimelineCloseDiff(1)}) | endif
  autocmd BufEnter * call s:RevealInTree()
  autocmd BufWritePost * call timer_start(0, {-> s:RevealInTree()})
  " (open beside / below as in every list: the tree's own s / i keep working)
  autocmd FileType nerdtree nmap <buffer> <silent> <C-v> s| nmap <buffer> <silent> <C-x> i
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
  autocmd CursorMoved,TextChanged,WinScrolled,WinEnter * if &filetype ==# 'nerdtree' && win_gettype() ==# '' | call s:TreeHover() | endif
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
  nnoremap <buffer> <silent> <C-l> :call <SID>PixAgain()<CR>
  call s:ViewFill(a:buf, ['', '  Loading ' . expand('%:t') . ' ...'])
  if a:kind ==# 'pdf'
    nnoremap <buffer> <silent> t :call <SID>PdfToggle()<CR>
    " (in the text: the keys as usual, n the next match)
    for [s:k, s:n] in [['n', 1], ['<PageDown>', 1], ['p', -1], ['<PageUp>', -1]]
      execute 'nnoremap <buffer> <silent> <expr>' s:k 'get(b:, "vimzip_page", 0) ? ":<C-u>call <SID>PdfPage(' . s:n
            \ . ' * v:count1)<CR>" : "' . substitute(s:k, '<', '\\<', '') . '"'
    endfor
    call s:PdfOpen(a:buf)
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
    call s:PdfOpen(a:buf)
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
" pictures in real pixels where the terminal can draw them (g:vimzip_images: 'auto', or 'sixel',
" 'kitty', 'octants', 'blocks'): kitty and Ghostty by kitty's own way, the terminals that tell vim they draw
" sixel (Windows Terminal, Konsole, WezTerm, foot, xterm, VTE built with it) by sixel; not inside
" tmux. Elsewhere half blocks, two pixels a cell.
function! s:Pixels(buf) abort
  let want = get(g:, 'vimzip_images', 'auto')
  if want !=# 'auto' || getbufvar(a:buf, 'vimzip_pix_failed', 0)
    return want =~# '^\(sixel\|kitty\)$' && !getbufvar(a:buf, 'vimzip_pix_failed', 0) ? want : ''
  endif
  if has('gui_running') || $TMUX !=# '' || $TERM =~# '^screen'
    return ''
  endif
  if &termguicolors && ($KITTY_WINDOW_ID !=# '' || $TERM =~# 'kitty\|ghostty' || $TERM_PROGRAM ==# 'ghostty')
    return 'kitty'
  endif
  " (the answer to vim's question at start, DA1: 4 among its numbers is sixel)
  return v:termda1 =~# '[?;]4[;c]' ? 'sixel' : ''
endfunction
" without pixels, a cell split in 2 x 4 parts (the octants of Unicode 16) where the terminal draws
" those characters itself, as VTE 0.80 does (GNOME Terminal, Terminator...): four times finer than half
" blocks. g:vimzip_images = 'octants' for others whose font has them.
function! s:Octants() abort
  let want = get(g:, 'vimzip_images', 'auto')
  return want ==# 'octants' || want ==# 'auto' && str2nr($VTE_VERSION) >= 8000
endfunction
" a cell's size in screen pixels: the terminal's, or g:vimzip_cell_pixels
function! s:CellPixels() abort
  let c = get(g:, 'vimzip_cell_pixels', [])
  if type(c) == v:t_list && len(c) == 2
    return c
  endif
  " (Windows Terminal draws sixel as if its cells were 10 x 20, whatever the font)
  if $WT_SESSION !=# ''
    return [10, 20]
  endif
  let c = exists('*getcellpixels') ? getcellpixels() : []
  return len(c) == 2 && c[0] > 0 && c[1] > 0 ? c : [10, 20]
endfunction
" the window's size in cells for the picture, under the header line and a blank one
function! s:ImgRender(buf) abort
  let w = bufwinid(a:buf)
  let page = getbufvar(a:buf, 'vimzip_page', 0)
  if w < 0 || getbufvar(a:buf, 'vimzip_view') !=# 'image' && !page
    return
  endif
  let size = [max([4, winwidth(w) - 2]), max([2, winheight(w) - 3])]
  let kind = s:Pixels(a:buf)
  let key = size + [kind] + (page ? [page] : [])
  if page && kind ==# ''
    " (the terminal no longer draws pixels: the PDF's text)
    call setbufvar(a:buf, 'vimzip_page', 0)
    call s:PdfRead(a:buf)
    return
  endif
  if getbufvar(a:buf, 'vimzip_size', []) == key
    return
  endif
  call setbufvar(a:buf, 'vimzip_size', key)
  if !executable(s:view)
    call s:ViewFill(a:buf, ['', '  vimzip-view is missing from ' . fnamemodify(s:view, ':h') . ': o opens the picture elsewhere'])
    return
  endif
  let out = []
  if page
    " a PDF's page: drawn by pdftoppm at the size it is shown, fitted by vimzip-view
    let cell = s:CellPixels()
    let [pw, ph] = getbufvar(a:buf, 'vimzip_pdf_size', [612, 792])
    let [mw, mh] = [size[0] * cell[0], size[1] * cell[1]]
    let fit = mw * ph > mh * pw ? '-scale-to-x -1 -scale-to-y ' . mh : '-scale-to-x ' . mw . ' -scale-to-y -1'
    let cmd = ['sh', '-c', printf('pdftoppm -f %d -l %d -png %s -singlefile %s | %s %s - %d %d %d %d', page, page, fit,
          \ shellescape(s:ViewFile(a:buf)), shellescape(s:view), kind, size[0], size[1], cell[0], cell[1])]
    let Done = {-> s:PixShow(a:buf, out, key)}
  elseif kind !=# ''
    let cell = s:CellPixels()
    let cmd = [s:view, kind, s:ViewFile(a:buf), size[0], size[1], cell[0], cell[1]]
    let Done = {-> s:PixShow(a:buf, out, key)}
  else
    let cmd = [s:view, s:Octants() ? 'cells' : 'image', s:ViewFile(a:buf), size[0], size[1]] + (&termguicolors ? [] : ['256'])
    let Done = {-> s:ImgShow(a:buf, out, size)}
  endif
  call job_start(cmd, {'out_cb': {_, l -> add(out, l)}, 'err_cb': {_, l -> add(out, 'error: ' . l)},
        \ 'close_cb': {_ -> Done()}})
endfunction
function! s:ImgShow(buf, out, size) abort
  " (gone, or resized again while drawing: that drawing is not shown)
  if !bufexists(a:buf) || getbufvar(a:buf, 'vimzip_size', [])[: 1] != a:size
    return
  endif
  call s:PixForget(a:buf)
  if empty(a:out) || a:out[0] =~# '^error: '
    let msg = empty(a:out) ? 'no output' : substitute(a:out[0], '^error: \(vimzip-view: \)\=', '', '')
    call s:ViewFill(a:buf, [s:ViewHeader(a:buf, 'cannot be shown'), '', '  ' . msg])
    return
  endif
  let [dims, format] = split(a:out[0] . ' ?')[0 : 1]
  let [rows, props] = s:BlockRows(a:out[1 :], a:size[0])
  call s:ViewFill(a:buf, [s:ViewHeader(a:buf, format . ' ' . substitute(dims, 'x', ' x ', '')), ''] + rows)
  for [lnum, col, length, name] in props
    call prop_add(lnum + 2, col, {'length': length, 'type': name, 'bufnr': a:buf})
  endfor
endfunction
" vimzip-view's rows of half blocks: [lines, [[line, col, length, group], ...]], centered in width
function! s:BlockRows(rows, width) abort
  let [lines, props] = [[], []]
  let gui = &termguicolors
  for row in a:rows
    let runs = map(split(row), 'split(v:val, ":")')
    let width = eval(join(map(copy(runs), 'v:val[0]'), '+'))
    let text = repeat(' ', max([0, (a:width - width) / 2]) + 1)
    for run in runs
      " (half blocks: the upper half in the first color; octants: the character says which parts)
      let [n, top, bottom] = run[: 2]
      let ch = len(run) > 3 ? nr2char(str2nr(run[3], 16)) : '▀'
      " a group per color, not per pair of them (vim has room for about 20000 groups): one
      " property gives the upper half's color, another the lower's, and vim combines the two
      for [name, hl] in [['VimzipImgF_' . top, (gui ? 'guifg=#' : 'ctermfg=') . top],
            \            ['VimzipImgB_' . bottom, (gui ? 'guibg=#' : 'ctermbg=') . bottom]]
        call s:ImgGroup(name, hl)
        call add(props, [len(lines) + 1, len(text) + 1, str2nr(n) * len(ch), name])
      endfor
      let text .= repeat(ch, str2nr(n))
    endfor
    call add(lines, text)
  endfor
  return [lines, props]
endfunction
function! s:ImgGroup(name, hl) abort
  if !has_key(s:img_hl, a:name)
    let s:img_hl[a:name] = a:hl
    execute 'highlight' a:name a:hl
    call prop_type_add(a:name, {'highlight': a:name})
  endif
endfunction
" the picture from vimzip-view in pixels: its first line says the cells it takes
function! s:PixShow(buf, out, key) abort
  if !bufexists(a:buf) || getbufvar(a:buf, 'vimzip_size', []) != a:key
    return
  endif
  if len(a:out) < 2 || a:out[0] =~# '^error: ' || a:out[1] =~# '^error: '
    if len(a:key) > 3
      " (a page pdftoppm could not draw: the text)
      call setbufvar(a:buf, 'vimzip_page', 0)
      call s:PdfRead(a:buf)
      return
    endif
    " (a picture the terminal's way could not make: half blocks, which say why if they fail too)
    call setbufvar(a:buf, 'vimzip_pix_failed', 1)
    call setbufvar(a:buf, 'vimzip_size', [])
    call s:ImgRender(a:buf)
    return
  endif
  call s:PixForget(a:buf)
  let [dims, format, cols, rows] = split(a:out[0])
  let [cols, rows] = [str2nr(cols), str2nr(rows)]
  let pad = max([0, (a:key[0] - cols) / 2]) + 1
  let pages = getbufvar(a:buf, 'vimzip_pages', 0)
  let header = len(a:key) > 3 ? s:ViewHeader(a:buf, printf('page %d%s   n p: pages   t: text', a:key[3], pages ? ' of ' . pages : ''))
        \ : s:ViewHeader(a:buf, format . ' ' . substitute(dims, 'x', ' x ', ''))
  if a:key[2] ==# 'kitty'
    " sent once, then shown by the placeholders in the text, which vim scrolls and redraws as any
    " text (the image's number is their color)
    let id = 0xA000 + a:buf
    call s:KittySend(id, a:out[1], cols, rows)
    let name = 'VimzipKitty' . id
    call s:ImgGroup(name, printf('guifg=#%06x', id))
    let rows_text = a:out[2 :]
    call s:ViewFill(a:buf, [header, ''] + map(copy(rows_text), 'repeat(" ", pad) . v:val'))
    for i in range(len(rows_text))
      call prop_add(i + 3, pad + 1, {'length': len(rows_text[i]), 'type': name, 'bufnr': a:buf})
    endfor
    call setbufvar(a:buf, 'vimzip_pix', {'kind': 'kitty', 'id': id})
  else
    call s:ViewFill(a:buf, [header, ''] + repeat([''], rows))
    call setbufvar(a:buf, 'vimzip_pix', {'kind': 'sixel', 'items': [{'lnum': 3, 'data': a:out[1 :], 'col': pad}]})
    call s:PixDraw(1)
  endif
endfunction
function! s:KittySend(id, data, cols, rows) abort
  let [i, n] = [0, len(a:data)]
  while i < n
    let more = i + 4096 < n
    " (q=2: no answers, which vim would take for typed keys)
    let ctl = i == 0 ? printf('a=T,U=1,f=100,i=%d,c=%d,r=%d,q=2,m=%d', a:id, a:cols, a:rows, more) : 'm=' . more
    call echoraw("\e_G" . ctl . ';' . a:data[i : i + 4095] . "\e\\")
    let i += 4096
  endwhile
endfunction
" a picture shown before (another size, or the buffer goes): the terminal's copy let go
function! s:PixForget(buf) abort
  let p = getbufvar(a:buf, 'vimzip_pix', {})
  for id in get(p, 'kind', '') ==# 'kitty' ? get(p, 'ids', [get(p, 'id', 0)]) : []
    call echoraw(printf("\e_Ga=d,d=I,i=%d,q=2\e\\", id))
  endfor
  call setbufvar(a:buf, 'vimzip_pix', {})
endfunction
" sixel pictures are drawn over vim's screen, which does not know they are there: drawn again
" whenever the windows, their scrolling or a popup over them change (vim redraws everything first:
" what it drew over them as blank left pieces behind), and not while a popup covers them
let s:pix_sig = ''
let s:pix_shown = 0
function! s:PixDraw(force) abort
  let wins = gettabinfo(tabpagenr())[0].windows
  " each row of cells of each picture in view: [screen row, col, its sixel]
  let todo = []
  for w in wins
    let p = getbufvar(winbufnr(w), 'vimzip_pix', {})
    if get(p, 'kind', '') ==# 'sixel'
      let col = win_screenpos(w)[1]
      for it in p.items
        for r in range(len(it.data))
          let row = screenpos(w, it.lnum + r, 1).row
          if row && !s:PixCovered([row, col + it.col, 1, winwidth(w) - it.col])
            call add(todo, [row, col + it.col, it.data[r]])
          endif
        endfor
      endfor
    endif
  endfor
  if empty(todo) && !s:pix_shown
    return
  endif
  let sig = string([tabpagenr(), &lines, &columns, map(copy(todo), 'v:val[0 : 1] + [len(v:val[2])]'),
        \ map(copy(wins), '[v:val, winbufnr(v:val), win_screenpos(v:val), winwidth(v:val), winheight(v:val)]')])
  if !a:force && sig ==# s:pix_sig
    return
  endif
  let s:pix_sig = sig
  " (the screen brought up to date first: lines vim still had to draw cleared the picture)
  if s:pix_shown
    redraw!
  else
    redraw
  endif
  let s:pix_shown = !empty(todo)
  if s:pix_shown
    call echoraw("\e7" . join(map(todo, '"\e[" . v:val[0] . ";" . v:val[1] . "H" . v:val[2]'), '') . "\e8")
  endif
endfunction
function! s:PixAgain() abort
  redraw!
  let s:pix_shown = 0
  call s:PixDraw(1)
endfunction
function! s:PixCovered(r) abort
  if empty(a:r)
    return 0
  endif
  for id in popup_list()
    let p = popup_getpos(id)
    if get(p, 'visible', 0) && p.line <= a:r[0] + a:r[2] - 1 && p.line + p.height - 1 >= a:r[0]
          \ && p.col <= a:r[1] + a:r[3] - 1 && p.col + p.width - 1 >= a:r[1]
      return 1
    endif
  endfor
  return 0
endfunction
" a PDF: its pages as pictures where the terminal draws pixels and pdftoppm (poppler) is there, t
" for its text (to search and copy); else the text
function! s:PdfOpen(buf) abort
  if getbufvar(a:buf, 'vimzip_pdf_text', 0) || s:Pixels(a:buf) ==# '' || !executable('pdftoppm')
    call setbufvar(a:buf, 'vimzip_page', 0)
    call s:PdfRead(a:buf)
    return
  endif
  let info = executable('pdfinfo') ? systemlist('pdfinfo ' . shellescape(s:ViewFile(a:buf))) : []
  let n = str2nr(matchstr(join(info, "\n"), 'Pages:\s*\zs\d\+'))
  let size = matchlist(join(info, "\n"), 'Page size:\s*\([0-9.]\+\) x \([0-9.]\+\)')
  call setbufvar(a:buf, 'vimzip_pages', n)
  call setbufvar(a:buf, 'vimzip_pdf_size', empty(size) ? [612, 792] : [str2float(size[1]), str2float(size[2])])
  call setbufvar(a:buf, 'vimzip_page', max([1, getbufvar(a:buf, 'vimzip_page', 1)]))
  call setbufvar(a:buf, 'vimzip_size', [])
  call s:ImgRender(a:buf)
endfunction
function! s:PdfPage(step) abort
  let page = get(b:, 'vimzip_page', 0)
  if !page
    return
  endif
  let last = get(b:, 'vimzip_pages', 0)
  let to = max([1, last ? min([last, page + a:step]) : page + a:step])
  if to != page
    let b:vimzip_page = to
    call s:ImgRender(bufnr(''))
  endif
endfunction
function! s:PdfToggle() abort
  let b:vimzip_pdf_text = get(b:, 'vimzip_page', 0) > 0
  " (back to the page it was on)
  let b:vimzip_page = b:vimzip_pdf_text ? b:vimzip_page : get(b:, 'vimzip_pdf_last', 1)
  let b:vimzip_pdf_last = b:vimzip_page
  call s:PixForget(bufnr(''))
  let b:vimzip_size = []
  call s:PdfOpen(bufnr(''))
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
  let lines = [s:ViewHeader(a:buf, len(pages) . (len(pages) == 1 ? ' page' : ' pages') . ', text by ' . a:tool
        \ . (s:Pixels(a:buf) !=# '' && executable('pdftoppm') ? '   t: pages' : ''))]
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
  if s:OpenExternal(s:ViewFile(bufnr('')))
    echo 'Opened in the system viewer: ' . expand('%:t')
  else
    echohl WarningMsg | echo 'No system viewer here (xdg-open), e.g. over ssh' | echohl None
  endif
endfunction
" a file or link in the system's own program (viewer, browser): 0 where there is none (over ssh)
function! s:OpenExternal(target) abort
  let t = a:target
  if executable('wslpath') && executable('explorer.exe') && !executable('wslview')
    " (a link as it is; a file by its Windows path)
    let cmd = ['explorer.exe', t =~# '^\a\+://' ? t : trim(system('wslpath -w ' . shellescape(t)))]
  else
    " (not open: on some Linux systems that is openvt, which starts a console)
    let cmd = map(filter(['xdg-open', 'wslview'], 'executable(v:val)')[: 0], '[v:val, t]')
    let cmd = empty(cmd) ? [] : cmd[0]
  endif
  if empty(cmd) || $DISPLAY ==# '' && $WAYLAND_DISPLAY ==# '' && cmd[0] ==# 'xdg-open'
    return 0
  endif
  call job_start(cmd, {'stoponexit': '', 'in_io': 'null', 'out_io': 'null', 'err_io': 'null'})
  return 1
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
  autocmd SafeState,SafeStateAgain * call s:PixDraw(0)
  " (a long message or a prompt scrolled the screen, vim came back from the background: again)
  autocmd CmdlineLeave,VimResume,FocusGained * let s:pix_sig = ''
  autocmd BufWipeout,BufUnload * call s:PixForget(str2nr(expand('<abuf>')))
  " (the terminal's answer came after a picture was opened: in pixels now)
  autocmd TermResponseAll da1 for s:b in getbufinfo({'bufloaded': 1}) | if getbufvar(s:b.bufnr, 'vimzip_view') ==# 'image'
        \ | call setbufvar(s:b.bufnr, 'vimzip_size', []) | call s:ImgRender(s:b.bufnr) | endif | endfor
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
nnoremap <silent> <leader>fp :call <SID>PickProject()<CR>
function! s:Selection() abort
  return join(getregion(getpos("'<"), getpos("'>"), {'type': visualmode()}), "\n")
endfunction

" tabs and files
nnoremap <silent> <Tab> :call <SID>Buf('bnext')<CR>
nnoremap <silent> <S-Tab> :call <SID>Buf('bprevious')<CR>
nnoremap <silent> <leader>q :call <SID>CloseBuf()<CR>
nnoremap <silent> <C-s> :call <SID>Save()<CR>
inoremap <silent> <C-s> <C-o>:call <SID>Save()<CR>
xnoremap <silent> <C-s> <Esc>:call <SID>Save()<CR>
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

" links and file names: Ctrl+click (VSCode's), or gx at the cursor, in the files and the terminals.
" A link opens in the browser (over ssh, where there is none, it is copied); a file name, with
" its :line:col (file.c:12:5, file.c(12), Python's File "x.py", line 12, a/ b/ of a diff), in the
" editor at that place; a folder in the tree. Ctrl+click on anything else goes to its definition.
function! s:LinkAt(text, col, dir) abort
  let [t, c] = [a:text, a:col]
  " (the match of pattern that covers the column: [text, start] or [])
  let Covering = {pat -> s:Covering(t, c, pat)}
  " (anywhere on a Markdown link, its text too: where it goes)
  let md = Covering('\[[^\]]*\]([^) ]\+\%(\s\+"[^"]*"\)\=)')
  let md = empty(md) ? [] : [matchstr(md[0], '\](\zs[^) ]\+'), md[1]]
  let m = !empty(md) ? md : Covering('\%(https\=\|ftp\|file\)://[^[:space:]<>"''`]\+')
  if !empty(m) && m[0] =~# '^\a\+://'
    let url = s:LinkTrim(m[0])
    if url !~# '^file://'
      return ['url', url]
    endif
    let m = [substitute(url, '^file://', '', ''), 0]
  endif
  " Python: File "x.py", line 12
  let py = matchlist(t, 'File "\([^"]\+\)", line \(\d\+\)')
  if !empty(py) && c > stridx(t, 'File "') && c <= matchend(t, 'File "[^"]\+", line \d\+')
    return s:LinkFile(py[1], str2nr(py[2]), 0, a:dir)
  endif
  if empty(m)
    let m = Covering('\f\+\%(:\d\+\%(:\d\+\)\=\|(\d\+\%(,\s*\d\+\)\=)\)\=')
  endif
  if empty(m)
    return []
  endif
  let p = matchlist(m[0], '^\(.\{-}\)\%(:\(\d\+\)\%(:\(\d\+\)\)\=\|(\(\d\+\)\%(,\s*\(\d\+\)\)\=)\)\=$')
  return s:LinkFile(p[1], str2nr(p[2] . p[4]), str2nr(p[3] . p[5]), a:dir)
endfunction
function! s:Covering(text, col, pat) abort
  let start = 0
  while 1
    let [m, s, e] = matchstrpos(a:text, a:pat, start)
    if s < 0 || s >= a:col
      return []
    endif
    if a:col <= e
      return [m, s]
    endif
    let start = max([e, s + 1])
  endwhile
endfunction
" (a link's end without the sentence's punctuation, or a closing bracket it did not open)
function! s:LinkTrim(url) abort
  let u = substitute(a:url, '[.,;:!?''"]\+$', '', '')
  while u =~# ')$' && count(u, ')') > count(u, '(')
    let u = u[: -2]
  endwhile
  return u
endfunction
" ['file', path, line, col] for a name that is there (from this file's folder, then the project's),
" else []
function! s:LinkFile(name, lnum, col, dir) abort
  let n = substitute(a:name, '[.,;:]\+$', '', '')
  " (a name with a / or a . : a word in the code is a name to look up, not a file)
  if n !~# '[/.]' || n =~# '^\.\+$'
    return []
  endif
  let n = n =~# '^\~' ? expand(n) : n
  let tries = n =~# '^/' ? [n] : [a:dir . '/' . n, getcwd() . '/' . n]
  " (git's a/ and b/ in a diff)
  if n =~# '^[ab]/'
    call extend(tries, [a:dir . '/' . n[2 :], getcwd() . '/' . n[2 :]])
  endif
  for f in tries
    if filereadable(f) || isdirectory(f)
      return ['file', simplify(fnamemodify(f, ':p')), a:lnum, a:col]
    endif
  endfor
  return []
endfunction
" the folder a terminal's shell is in now (it may have cd'd), else vim's
function! s:TermCwd(buf) abort
  let job = term_getjob(a:buf)
  let pid = job_status(job) ==# 'run' ? job_info(job).process : 0
  let d = pid ? resolve('/proc/' . pid . '/cwd') : ''
  return isdirectory(d) ? d : getcwd()
endfunction
function! s:LinkOpen(link) abort
  if a:link[0] ==# 'url'
    if s:OpenExternal(a:link[1])
      call s:Say('Opened in the browser: ' . a:link[1])
    else
      " (to the system's clipboard: vim's, else the terminal's own way, OSC 52; and to p)
      if has('clipboard_working')
        call setreg('+', a:link[1])
      else
        call echoraw("\e]52;c;" . base64_encode(str2blob([a:link[1]])) . "\x07")
      endif
      call setreg('"', a:link[1])
      call s:Say('No browser here: the link is copied (' . a:link[1] . ')')
    endif
    return
  endif
  let [_, f, lnum, col] = a:link
  call s:EditWin()
  normal! m'
  execute 'edit' fnameescape(fnamemodify(f, ':~:.'))
  if lnum > 0
    call cursor(lnum, max([1, col]))
    normal! zz
  endif
endfunction
" the link or file name in a window at a line and column
function! s:LinkIn(win, lnum, col) abort
  let b = winbufnr(a:win)
  let dir = getbufvar(b, '&buftype') ==# 'terminal' ? s:TermCwd(b) : fnamemodify(bufname(b), ':p:h')
  return s:LinkAt(get(getbufline(b, a:lnum), 0, ''), a:col, isdirectory(dir) ? dir : getcwd())
endfunction
function! s:CtrlClick() abort
  let m = getmousepos()
  if !m.winid || m.line < 1
    return
  endif
  let link = s:LinkIn(m.winid, m.line, m.column)
  if !empty(link)
    call s:LinkOpen(link)
  elseif getbufvar(winbufnr(m.winid), '&buftype') ==# ''
    " (VSCode's Ctrl+click on a name: its definition)
    call win_gotoid(m.winid)
    call cursor(m.line, m.column)
    call s:GoDef()
  else
    call win_gotoid(m.winid)
  endif
endfunction
function! s:OpenAtCursor() abort
  let link = s:LinkIn(win_getid(), line('.'), col('.'))
  if empty(link)
    call s:Say('No link or file name under the cursor')
  else
    call s:LinkOpen(link)
  endif
endfunction
nnoremap <silent> <C-LeftMouse> :call <SID>CtrlClick()<CR>
inoremap <silent> <C-LeftMouse> <C-o>:call <SID>CtrlClick()<CR>
tnoremap <silent> <C-LeftMouse> <C-w>:call <SID>CtrlClick()<CR>
nnoremap <silent> gx :call <SID>OpenAtCursor()<CR>

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
  elseif expand('<cword>') =~# '^\w\+$'
    " the whole word only: calc should not list every calc_add and calc_eval
    let w = expand('<cword>')
    call s:EditWin()
    call s:Find('\b' . w . '\b', 0)
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
" (on a line without one: a word saying so, not nothing at all)
function! s:ErrorDetail() abort
  if exists('g:loaded_ale') && empty(ale#util#FindItemAtCursor(bufnr(''))[1])
    echo 'No error or warning on this line'
  else
    ALEDetail
  endif
endfunction
nnoremap <silent> <leader>ce :call <SID>ErrorDetail()<CR>
nnoremap <silent> <leader>cl :Lsp<CR>

" a message on one line, cut to the screen's width (a longer one stopped everything at "Press
" ENTER" on a narrow screen)
function! s:Say(msg, ...) abort
  " (at least one cell: in a terminal 12 wide or less the cutting never ended)
  let room = max([1, &columns - 12])
  let msg = a:msg
  if strdisplaywidth(msg) > room
    " (by screen cells: a Hangul letter takes two)
    let msg = strcharpart(msg, 0, room)
    while strdisplaywidth(msg) > room - 1
      let msg = strcharpart(msg, 0, strchars(msg) - 1)
    endwhile
    let msg .= '…'
  endif
  execute 'echohl' (a:0 ? a:1 : 'None')
  echo msg
  echohl None
endfunction
" Space cr: rename the symbol at the cursor everywhere (VSCode's F2; vimzip's F2 is the tree): the
" language server's rename, or without one the word in this file
function! s:Rename() abort
  let w = expand('<cword>')
  if w !~# '^\h\w*$'
    call s:Say('No name under the cursor')
    return
  endif
  if s:LspHere()
    ALERename
    return
  endif
  let new = inputdialog('Rename ' . w . ' in this file (no language server: :Lsp) to: ', w, '')
  if new ==# '' || new ==# w
    return
  endif
  let view = winsaveview()
  let n = len(filter(getline(1, '$'), 'v:val =~# ''\V\C\<'' . escape(w, ''\'') . ''\>'''))
  execute 'keeppatterns %s/\V\C\<' . escape(w, '/\') . '\>/' . escape(new, '/\&~') . '/ge'
  call winrestview(view)
  redraw
  call s:Say(printf('Renamed %s to %s on %d line%s', w, new, n, n == 1 ? '' : 's'))
endfunction

" Space cf: format the file (VSCode's Format Document) with the formatter of its language when one
" is installed, else vim's reindent (where vim knows the language's indent). Saving (Ctrl+s, :w;
" not the autosave while typing) formats too where the project asks for it with the formatter's
" settings file (.clang-format, .prettierrc, rustfmt.toml, [tool.ruff.format] or [tool.black] in
" pyproject.toml...), and Go and Zig files always (gofmt / zig fmt being their own style).
" g:vimzip_format_on_save = 0 never, 1 whenever installed.
let s:formatters = {'c': ['clang-format'], 'cpp': ['clang-format'], 'objc': ['clang-format'],
      \ 'cuda': ['clang-format'], 'java': ['google-java-format'], 'python': ['ruff', 'black'],
      \ 'go': ['gofmt'], 'rust': ['rustfmt'], 'sh': ['shfmt'], 'bash': ['shfmt'], 'lua': ['stylua'],
      \ 'zig': ['zig'], 'cmake': ['cmake-format'], 'json': ['prettier', 'jq']}
for s:ft in ['javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'css', 'scss', 'less',
      \ 'html', 'vue', 'yaml', 'markdown', 'graphql']
  let s:formatters[s:ft] = ['prettier']
endfor
" [program, command for a file] of the first formatter installed for this buffer's language
function! s:Formatter() abort
  let file = expand('%:p')
  let dir = expand('%:p:h')
  for prog in get(s:formatters, &filetype, [])
    " (a project's own prettier first)
    let exe = prog ==# 'prettier' ? findfile('node_modules/.bin/prettier', dir . ';') : ''
    let exe = exe !=# '' ? fnamemodify(exe, ':p') : exepath(prog)
    if exe ==# ''
      continue
    endif
    let edition = prog ==# 'rustfmt' ? matchstr(join(readfile(findfile('Cargo.toml', dir . ';') ?? '/dev/null'), "\n"), 'edition\s*=\s*"\zs\d\+') : ''
    let cmd = {'clang-format': [exe, '--assume-filename=' . file],
          \ 'google-java-format': [exe, '-'],
          \ 'ruff': [exe, 'format', '--stdin-filename', file, '-'],
          \ 'black': [exe, '-q', '--stdin-filename', file, '-'],
          \ 'gofmt': [exe],
          \ 'rustfmt': [exe, '--edition', edition !=# '' ? edition : '2021'],
          \ 'shfmt': [exe] + (&expandtab ? ['-i', string(shiftwidth())] : []),
          \ 'stylua': [exe, '--stdin-filepath', file, '-'],
          \ 'zig': [exe, 'fmt', '--stdin'],
          \ 'cmake-format': [exe, '-'],
          \ 'prettier': [exe, '--stdin-filepath', file],
          \ 'jq': [exe, '--indent', string(min([7, max([1, shiftwidth()])])), '.']}[prog]
    return [prog, cmd]
  endfor
  return ['', []]
endfunction
" does the project ask for its formatter (a settings file for it above this file)?
function! s:FormatWanted(prog) abort
  let want = get(g:, 'vimzip_format_on_save', 'auto')
  if want isnot# 'auto' || a:prog ==# ''
    return a:prog !=# '' && want is# 1
  endif
  if a:prog ==# 'gofmt' || a:prog ==# 'zig'
    return 1
  endif
  let dir = expand('%:p:h')
  let files = {'clang-format': ['.clang-format', '_clang-format'],
        \ 'rustfmt': ['rustfmt.toml', '.rustfmt.toml'], 'stylua': ['stylua.toml', '.stylua.toml'],
        \ 'cmake-format': ['.cmake-format', '.cmake-format.py', '.cmake-format.yaml', '.cmake-format.json'],
        \ 'prettier': ['.prettierrc', '.prettierrc.json', '.prettierrc.yaml', '.prettierrc.yml',
        \   '.prettierrc.js', '.prettierrc.cjs', '.prettierrc.mjs', '.prettierrc.toml',
        \   'prettier.config.js', 'prettier.config.cjs', 'prettier.config.mjs']}
  for f in get(files, a:prog, [])
    if findfile(f, dir . ';') !=# ''
      return 1
    endif
  endfor
  " (or a section in the project's own file; ruff's settings are often for its checks only, so its
  " format section)
  let section = {'ruff': '^\[\(tool\.ruff\.\)\=format\]', 'black': '^\[tool\.black\]', 'prettier': '"prettier"\s*:'}
  let in = {'prettier': ['package.json'], 'ruff': ['pyproject.toml', 'ruff.toml', '.ruff.toml'], 'black': ['pyproject.toml']}
  for name in get(in, a:prog, [])
    let f = findfile(name, dir . ';')
    if f !=# '' && match(readfile(f), section[a:prog]) >= 0
      return 1
    endif
  endfor
  return 0
endfunction
function! s:Format(saving) abort
  if &buftype !=# '' || !&modifiable || exists('b:vimzip_view')
    return
  endif
  let [prog, cmd] = s:Formatter()
  if a:saving && !s:FormatWanted(prog)
    return
  endif
  if prog ==# ''
    " (vim's reindent only where it knows the language's indent rules: without them it gave every
    " line the one above's, a text file's indents all gone)
    if &indentexpr ==# '' && !&cindent && !&lisp && &equalprg ==# ''
      if !a:saving
        call s:Say('No formatter for ' . (&filetype !=# '' ? &filetype : 'this file') . (has_key(s:formatters, &filetype) ? ' (install ' . join(s:formatters[&filetype], ' or ') . ')' : ''))
      endif
      return
    endif
    let view = winsaveview()
    silent keepjumps normal! gg=G
    call winrestview(view)
    call s:Say('Reindented' . (has_key(s:formatters, &filetype) ? ' (to format: install ' . join(s:formatters[&filetype], ' or ') . ')' : ''))
    return
  endif
  let err = tempname()
  let lines = getline(1, '$')
  let out = systemlist(join(map(copy(cmd), 'shellescape(v:val)')) . ' 2>' . shellescape(err), lines)
  if v:shell_error
    let msg = filter(readfile(err), 'v:val =~# "\\S"')
    call delete(err)
    call s:Say('Not formatted (' . prog . '): ' . get(msg, 0, 'exit ' . v:shell_error), 'WarningMsg')
    return
  endif
  call delete(err)
  " (nothing back for a file with text in it: the formatter failed without saying so; the file
  " would have been emptied)
  if empty(out) && join(lines, '') =~# '\S'
    call s:Say('Not formatted (' . prog . '): it gave nothing back', 'WarningMsg')
    return
  endif
  if out ==# lines
    if !a:saving | call s:Say('Formatted (' . prog . '): no change') | endif
    return
  endif
  let view = winsaveview()
  call setline(1, out)
  if line('$') > len(out)
    silent execute 'keepjumps' (len(out) + 1) . ',$delete _'
  endif
  call winrestview(view)
  if !a:saving | call s:Say('Formatted (' . prog . ')') | endif
endfunction
" a save that is not the user's (the autosave, :wall before a build): no formatting
function! s:QuietWrite(cmd) abort
  let s:autosaving = 1
  try
    execute 'silent!' a:cmd
  finally
    let s:autosaving = 0
  endtry
endfunction
augroup vimzip_format
  autocmd!
  " (the file being written: :wall writes others too)
  autocmd BufWritePre * if !get(s:, 'autosaving') && str2nr(expand('<abuf>')) == bufnr('') | call s:Format(1) | endif
augroup END
" Ctrl+s also formats a file the autosave has already written
function! s:Save() abort
  if &buftype ==# '' && bufname('') ==# ''
    " a new file: asked where (VSCode's Save As; :update stopped at a press-ENTER error)
    let name = trim(input('Save as: ', '', 'file'))
    redraw
    if name ==# ''
      return
    endif
    let name = fnamemodify(expand(name), ':p')
    let bang = ''
    if filereadable(name)
      if confirm(fnamemodify(name, ':~:.') . ' exists. Replace it?', "&Yes\n&No", 2) != 1
        return
      endif
      let bang = '!'
    endif
    silent! call mkdir(fnamemodify(name, ':h'), 'p')
    try
      " (quietly, then one short line: with the question still above it, vim's own message stopped at
      " Press ENTER, and from insert mode the next letters typed ran as commands)
      silent execute 'write' . bang fnameescape(fnamemodify(name, ':~:.'))
      if &filetype ==# ''
        silent filetype detect
      endif
      redraw
      call s:Say('Saved ' . fnamemodify(name, ':~:.'))
    catch
      call s:Say(substitute(v:exception, '^Vim(\a\+):', '', ''), 'ErrorMsg')
    endtry
    return
  endif
  if !&modified
    let tick = b:changedtick
    call s:Format(1)
    if b:changedtick == tick
      return
    endif
  endif
  try
    update
  catch /E45:/
    call s:NotSaved(bufnr(''))
  catch
    call s:Say(substitute(v:exception, '^Vim(\a\+):', '', ''), 'ErrorMsg')
  endtry
endfunction

" Space ca / Ctrl+.: the language server's quick fixes and refactorings for this place (VSCode's
" lightbulb), in a menu
function! s:CodeAction() abort
  if !s:LspHere()
    call s:Say('No quick fixes: they come from a language server (:Lsp)')
    return
  endif
  let s:actions = {'items': [], 'buf': bufnr(''), 'timer': -1}
  " (asked at the problem on this line where there is one: ALE sends the server the problem, and so
  " gets its fix, only for a single place, not a word)
  let item = ale#util#FindItemAtCursor(bufnr(''))[1]
  if !empty(item)
    call setpos("'<", [0, item.lnum, max([1, get(item, 'col', 1)]), 0])
    call setpos("'>", [0, item.lnum, max([1, get(item, 'col', 1)]), 0])
  endif
  call ale#codefix#Execute(!empty(item), function('s:CodeActions'))
endfunction
function! s:CodeActions(data, items) abort
  " (several servers or requests answer apart: shown together once they are in)
  call extend(s:actions.items, map(copy(a:items), '[a:data, v:val[0], v:val[1]]'))
  call timer_stop(s:actions.timer)
  let s:actions.timer = timer_start(150, {-> s:CodeActionMenu()})
endfunction
function! s:CodeActionMenu() abort
  if bufnr('') != s:actions.buf
    return
  endif
  let items = filter(s:actions.items, '!empty(v:val[0])')
  if empty(items)
    call s:Say('No quick fixes here')
    return
  endif
  let titles = map(copy(items), {i, v -> printf('%d  %s', i + 1, get(v[2], 'title', get(v[2], 'description', '?')))})
  call popup_menu(titles, {'title': ' Quick fix  Enter: apply  Esc: close ', 'callback': function('s:CodeActionPicked'),
        \ 'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1],
        \ 'pos': 'topleft', 'line': 'cursor+1', 'col': 'cursor', 'maxwidth': &columns - 4})
endfunction
function! s:CodeActionPicked(id, result) abort
  if a:result < 1
    return
  endif
  let [data, kind, item] = s:actions.items[a:result - 1]
  if kind ==# 'tsserver'
    call ale#codefix#ApplyTSServerCodeAction(data, item)
  else
    call ale#codefix#ApplyLSPCodeAction(data, item)
  endif
endfunction

" Space cp, or a click on E / W in the status bar: the problems of the open files (ALE's) and of the
" last build in one list at the bottom (VSCode's Problems panel); it follows new checks while open
let s:build_problems = []
function! s:ProblemItems() abort
  let items = []
  if exists('g:loaded_ale')
    for b in getbufinfo({'buflisted': 1, 'bufloaded': 1})
      for i in ale#engine#GetLoclist(b.bufnr)
        call add(items, {'bufnr': i.bufnr, 'lnum': i.lnum, 'col': get(i, 'col', 0), 'type': get(i, 'type', 'E'),
              \ 'text': i.text . (has_key(i, 'code') ? ' [' . i.code . ']' : '')})
      endfor
    endfor
  endif
  let seen = {}
  for i in items
    let seen[i.bufnr . ':' . i.lnum] = 1
  endfor
  " (the build's, where the checks did not already say so)
  for i in s:build_problems
    if !has_key(seen, get(i, 'bufnr', 0) . ':' . get(i, 'lnum', 0))
      call add(items, i)
    endif
  endfor
  return sort(items, {a, b -> a.bufnr != b.bufnr ? (bufname(a.bufnr) <# bufname(b.bufnr) ? -1 : 1)
        \ : a.type !=# b.type ? (a.type ==# 'E' ? -1 : b.type ==# 'E' ? 1 : 0) : a.lnum - b.lnum})
endfunction
function! s:ProblemsShown() abort
  return get(getqflist({'context': 0}), 'context', '') is# 'vimzip_problems'
endfunction
function! s:Problems() abort
  let items = s:ProblemItems()
  if s:ProblemsShown()
    call setqflist([], 'r', {'items': items, 'title': 'Problems'})
  else
    call setqflist([], ' ', {'items': items, 'title': 'Problems', 'context': 'vimzip_problems'})
  endif
  call s:EditWin()
  let from = win_getid()
  execute 'botright copen' max([6, min([12, len(items) + 1])])
  call win_gotoid(from)
  call s:Say(empty(items) ? 'No problems have been found in the open files' : '')
endfunction
function! s:ProblemsUpdate() abort
  if s:ProblemsShown() && getqflist({'winid': 0}).winid
    let view = getqflist({'idx': 0}).idx
    call setqflist([], 'r', {'items': s:ProblemItems(), 'title': 'Problems'})
    call setqflist([], 'r', {'idx': max([1, min([view, getqflist({'size': 0}).size])])})
  endif
endfunction
function! VimzipProblemsClick(info) abort
  if a:info.button ==# 'l'
    call s:Problems()
  endif
  return 0
endfunction
augroup vimzip_problems
  autocmd!
  autocmd User ALELintPost call s:ProblemsUpdate()
augroup END

" Ctrl+Shift+b / Space cb: build the project in a panel at the bottom (VSCode's build task): CMake
" (into the project's build folder: its compile_commands.json is then the project's own), make,
" cargo, go, zig or npm's build script; g:vimzip_build sets the command. Its errors join the
" problems (Space cp, ]q).
function! s:BuildCommand() abort
  if get(g:, 'vimzip_build', '') !=# ''
    return g:vimzip_build
  endif
  let made = filter(glob('build*/CMakeCache.txt', 0, 1) + glob('cmake-build-*/CMakeCache.txt', 0, 1), 'filereadable(v:val)')
  if !empty(made)
    return 'cmake --build ' . shellescape(fnamemodify(made[0], ':h')) . ' -j'
  elseif filereadable('CMakeLists.txt')
    return 'cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON && cmake --build build -j'
  elseif filereadable('Makefile') || filereadable('makefile') || filereadable('GNUmakefile')
    return 'make -j' . s:jobs
  elseif filereadable('Cargo.toml')
    return 'cargo build --message-format short'
  elseif filereadable('go.mod')
    return 'go build ./...'
  elseif filereadable('build.zig')
    return 'zig build'
  elseif filereadable('package.json') && match(readfile('package.json'), '"build"\s*:') >= 0
    return 'npm run build'
  endif
  return ''
endfunction
function! s:Build() abort
  let cmd = s:BuildCommand()
  if cmd ==# ''
    call s:Say('Nothing to build here (CMakeLists.txt, Makefile, Cargo.toml, go.mod, build.zig, package.json), or let g:vimzip_build = ''...''')
    return
  endif
  call s:QuietWrite('wall')
  call s:EditWin()
  let from = win_getid()
  let old = get(s:, 'build', -1)
  if bufwinnr(old) > 0
    execute bufwinnr(old) . 'wincmd w'
    enew
  else
    execute 'botright' s:PanelSize('term') 'new'
  endif
  if bufexists(old)
    execute 'silent! bwipeout!' old
  endif
  let blank = bufnr('')
  " (the CMake setting for every build: a Makefile or script that runs CMake gets it too)
  let s:build = term_start([&shell, &shellcmdflag, cmd], {'curwin': 1, 'term_name': 'Build: ' . cmd,
        \ 'env': s:CMakeEnv(), 'term_kill': 'hup', 'exit_cb': {_, status -> timer_start(100, {-> s:BuildDone(status)})}})
  if bufexists(blank) && blank != s:build
    execute 'silent! bwipeout' blank
  endif
  setlocal winfixheight nonumber nocursorline signcolumn=no nolist
  " (q closes it once the build is over, as it closes the other panels)
  nnoremap <buffer> <silent> q :close<CR>
  call setbufvar(s:build, '&buflisted', 0)
  let s:set[win_getid()] = winheight(0)
  call win_gotoid(from)
  call s:Layout()
endfunction
function! s:Count(n, what) abort
  return a:n . ' ' . a:what . (a:n == 1 ? '' : 's')
endfunction
function! s:BuildDone(status) abort
  if !bufexists(get(s:, 'build', -1))
    return
  endif
  let lines = getbufline(s:build, 1, '$')
  let efm = &errorformat
  " (the kind of each message apart from its text, notes left out, Rust's error[E0425], and
  " TypeScript's file(line,col))
  let &errorformat = '%f:%l:%c: %trror: %m,%f:%l:%c: fatal %trror: %m,%f:%l:%c: %tarning: %m,'
        \ . '%f:%l:%c: %trror[%*[^]]]: %m,%f:%l:%c: %tarning[%*[^]]]: %m,'
        \ . '%-G%f:%l:%c: note: %m,%f(%l\,%c): %t%*[^ ] TS%n: %m,' . &errorformat
  let qf = getqflist({'lines': lines, 'efm': &errorformat}).items
  let &errorformat = efm
  let s:build_problems = map(filter(qf, 'v:val.valid && v:val.bufnr'), 'extend(v:val, {"type": v:val.type ==# "" ? "E" : toupper(v:val.type)})')
  let errors = len(filter(copy(s:build_problems), 'v:val.type ==# "E"'))
  call s:ProblemsUpdate()
  if a:status == 0
    call s:Say('Build succeeded' . (empty(s:build_problems) ? '' : printf(' (%s: Space cp)', s:Count(len(s:build_problems), 'warning'))))
  else
    call s:Say('Build failed' . (empty(s:build_problems) ? '' : printf(': %s, %s (Space cp lists them)', s:Count(errors, 'error'), s:Count(len(s:build_problems) - errors, 'warning'))), 'WarningMsg')
  endif
endfunction

" merge conflicts (<<<<<<< ... ======= ... >>>>>>>): colored as VSCode does, with the choices above
" each one; Space mc keeps the current change, Space mi the incoming one, Space mb both, ]x / [x go
" to the next / previous conflict
call sign_define('VimzipConflictMark', {'linehl': 'VimzipConflictMark'})
call sign_define('VimzipConflictCurrent', {'linehl': 'VimzipConflictCurrent'})
call sign_define('VimzipConflictIncoming', {'linehl': 'VimzipConflictIncoming'})
silent! call prop_type_add('vimzip_conflict', {'highlight': 'VimzipConflictHint'})
" [start, base (or 0), middle, end] of each conflict
function! s:Conflicts() abort
  let found = []
  let [start, base, mid] = [0, 0, 0]
  let lnum = 0
  for l in getline(1, '$')
    let lnum += 1
    if l =~# '^<<<<<<<\( \|$\)'
      let [start, base, mid] = [lnum, 0, 0]
    elseif start && l =~# '^|||||||\( \|$\)'
      let base = lnum
    elseif start && l =~# '^=======$'
      let mid = lnum
    elseif start && mid && l =~# '^>>>>>>>\( \|$\)'
      call add(found, [start, base, mid, lnum])
      let start = 0
    endif
  endfor
  return found
endfunction
function! s:ConflictMarks() abort
  if &buftype !=# '' || (!get(b:, 'vimzip_conflicts') && search('^<<<<<<<\( \|$\)', 'nw') == 0)
    return
  endif
  call sign_unplace('vimzip_conflict', {'buffer': bufnr('')})
  call prop_remove({'type': 'vimzip_conflict', 'all': 1})
  let found = s:Conflicts()
  let b:vimzip_conflicts = !empty(found)
  for [start, base, mid, end] in found
    for l in range(start, end)
      let kind = index([start, base, mid, end], l) >= 0 ? 'Mark' : l < (base ? base : mid) ? 'Current' : l > mid ? 'Incoming' : 'Mark'
      " (as high as ALE's marks, which then show too; over git's, which would hide the colors of a
      " file git tracks, every line of a conflict being a change)
      call sign_place(0, 'vimzip_conflict', 'VimzipConflict' . kind, bufnr(''), {'lnum': l, 'priority': get(g:, 'ale_sign_priority', 30)})
    endfor
    call prop_add(start, 0, {'type': 'vimzip_conflict', 'text_align': 'above',
          \ 'text': 'Accept Current (Space mc) │ Accept Incoming (Space mi) │ Accept Both (Space mb)'})
  endfor
endfunction
function! s:Resolve(which) abort
  let at = filter(s:Conflicts(), 'v:val[0] <= line(".") && line(".") <= v:val[3]')
  if empty(at)
    call s:Say('No merge conflict at the cursor (]x goes to the next one)')
    return
  endif
  let [start, base, mid, end] = at[0]
  let current = getline(start + 1, (base ? base : mid) - 1)
  let incoming = getline(mid + 1, end - 1)
  let keep = a:which ==# 'current' ? current : a:which ==# 'incoming' ? incoming : current + incoming
  " (added below it first: a file that was only the conflict would keep an empty line)
  call append(end, keep)
  silent execute 'keepjumps' start . ',' . end . 'delete _'
  call cursor(start, 1)
  call s:ConflictMarks()
endfunction
function! s:NextConflict(back) abort
  if !search('^<<<<<<<\( \|$\)', a:back ? 'bsw' : 'sw')
    call s:Say('No merge conflicts in this file')
  endif
endfunction
augroup vimzip_conflicts
  autocmd!
  autocmd BufWinEnter,BufWritePost,TextChanged,InsertLeave * call s:ConflictMarks()
augroup END

" several places at once (VSCode's Ctrl+d; vim's Ctrl+d stays half a page down): Ctrl+n on a word
" (or with a selection) picks it, each Ctrl+n more the next one (Ctrl+p one fewer, Ctrl+a all in
" the file); then c retypes them all at once, i / a type before / after each, d deletes them, and
" Esc stops
let s:multi = {}
let s:multi_keys = ['<C-p>', '<C-a>', 'c', 's', 'i', 'a', 'd', 'x', '<Esc>']
function! s:MultiOn() abort
  return !empty(s:multi) && s:multi.buf == bufnr('')
endfunction
function! s:MultiStart(text, word) abort
  call s:MultiStop()
  if a:text ==# '' || a:text =~# '\n'
    call s:Say('Ctrl+n: on a word, or with a selection on one line')
    return
  endif
  let s:multi = {'buf': bufnr(''), 'text': a:text, 'win': win_getid(), 'match': -1, 'pos': [],
        \ 'pat': '\V\C' . (a:word ? '\<' : '') . escape(a:text, '\') . (a:word ? '\>' : '')}
  for k in s:multi_keys
    execute 'nnoremap <buffer> <nowait> <silent>' k ':<C-u>call <SID>MultiKey("' . substitute(k, '<', '<lt>', 'g') . '")<CR>'
  endfor
  augroup vimzip_multi
    autocmd!
    autocmd BufLeave,WinLeave * call s:MultiStop()
  augroup END
endfunction
function! s:MultiStop() abort
  if empty(s:multi)
    return
  endif
  silent! call matchdelete(s:multi.match, s:multi.win)
  for k in s:multi_keys
    if bufnr('') == s:multi.buf
      execute 'silent! nunmap <buffer>' k
    elseif bufwinid(s:multi.buf) > 0
      silent! call win_execute(bufwinid(s:multi.buf), 'nunmap <buffer> ' . k)
    endif
  endfor
  silent! autocmd! vimzip_multi
  let s:multi = {}
endfunction
function! s:MultiShow() abort
  silent! call matchdelete(s:multi.match, s:multi.win)
  let s:multi.match = matchaddpos('VimzipMulti', map(copy(s:multi.pos), '[v:val[0], v:val[1], len(s:multi.text)]'), 20)
  let n = len(s:multi.pos)
  let msg = printf('%d selected   Ctrl+n next  Ctrl+p back  Ctrl+a all   c change  i/a type before/after  d delete  Esc stop', n)
  call s:Say(msg)
endfunction
" the next place after the last one picked (from the top again at the end)
function! s:MultiNext() abort
  let last = s:multi.pos[-1]
  call cursor(last[0], last[1])
  let n = len(s:multi.pos)
  for _ in range(n + 1)
    let p = searchpos(s:multi.pat, 'w')
    if p == [0, 0]
      break
    endif
    if index(s:multi.pos, p) < 0
      call add(s:multi.pos, p)
      return
    endif
  endfor
  call cursor(last[0], last[1])
  call s:Say('All ' . n . ' are picked')
endfunction
function! s:MultiAdd(visual) abort
  if &buftype !=# '' || !&modifiable
    return
  endif
  if !s:MultiOn()
    if a:visual
      let text = s:Selection()
      let start = getpos("'<")[1 : 2]
      call s:MultiStart(text, 0)
    else
      let text = expand('<cword>')
      call s:MultiStart(text, text =~# '^\k\+$')
      if empty(s:multi)
        return
      endif
      " (the word under the cursor, from its start)
      call search(s:multi.pat, 'bcW', line('.'))
      let start = getpos('.')[1 : 2]
      if strpart(getline(start[0]), start[1] - 1, len(text)) !=# text
        let start = searchpos(s:multi.pat, 'cW')
      endif
    endif
    if empty(s:multi)
      return
    endif
    call add(s:multi.pos, start)
    call cursor(start[0], start[1])
  else
    call s:MultiNext()
  endif
  call s:MultiShow()
endfunction
function! s:MultiKey(key) abort
  if !s:MultiOn()
    return
  endif
  let k = a:key
  if k ==# '<Esc>'
    call s:MultiStop()
    echo ''
  elseif k ==# '<C-p>'
    if len(s:multi.pos) > 1
      call remove(s:multi.pos, -1)
      call cursor(s:multi.pos[-1][0], s:multi.pos[-1][1])
      call s:MultiShow()
    else
      call s:MultiStop()
      echo ''
    endif
  elseif k ==# '<C-a>'
    let view = winsaveview()
    call cursor(1, 1)
    let p = searchpos(s:multi.pat, 'cW')
    while p != [0, 0] && len(s:multi.pos) < 10000
      if index(s:multi.pos, p) < 0
        call add(s:multi.pos, p)
      endif
      let p = searchpos(s:multi.pat, 'W')
    endwhile
    call winrestview(view)
    call s:MultiShow()
  else
    call s:MultiEdit(k ==# 's' ? 'c' : k ==# 'x' ? 'd' : k)
  endif
endfunction
function! s:MultiEdit(op) abort
  let [text, len] = [s:multi.text, len(s:multi.text)]
  " (still there: the file may have changed since they were picked)
  let pos = filter(copy(s:multi.pos), 'strpart(getline(v:val[0]), v:val[1] - 1, len) ==# text')
  call sort(pos, {a, b -> a[0] != b[0] ? a[0] - b[0] : a[1] - b[1]})
  if empty(pos)
    call s:MultiStop()
    return
  endif
  if a:op ==# 'd'
    for [l, c] in reverse(copy(pos))
      let t = getline(l)
      call setline(l, strpart(t, 0, c - 1) . strpart(t, c - 1 + len))
    endfor
    call cursor(pos[0][0], pos[0][1])
    call s:MultiStop()
    call s:Say('Deleted ' . len(pos))
    return
  endif
  let [l, c] = pos[0]
  let t = getline(l)
  let col = a:op ==# 'a' ? c + len : c
  " (the line once the first is retyped: vim's own c deletes it, in the same undo step as the typing)
  let line = a:op ==# 'c' ? strpart(t, 0, c - 1) . strpart(t, c - 1 + len) : t
  let edit = {'op': a:op, 'pos': pos, 'lnum': l, 'col': col, 'line': line, 'len': len, 'lines': line('$')}
  call s:MultiStop()
  let s:multi_edit = edit
  augroup vimzip_multi_edit
    autocmd!
    autocmd InsertLeave * ++once call s:MultiApply()
  augroup END
  call cursor(l, col)
  if a:op ==# 'c'
    " (ahead of what is already typed: a fast typist's letters came first, in normal mode)
    call feedkeys('"_c' . strchars(text) . 'l', 'ni')
  elseif col > len(t)
    startinsert!
  else
    startinsert
  endif
endfunction
" after typing in the first place: the same text in the others
function! s:MultiApply() abort
  let e = s:multi_edit
  unlet s:multi_edit
  let now = getline(e.lnum)
  let added = len(now) - len(e.line)
  if line('.') != e.lnum || line('$') != e.lines || added < 0
        \ || strpart(now, 0, e.col - 1) !=# strpart(e.line, 0, e.col - 1)
        \ || strpart(now, e.col - 1 + added) !=# strpart(e.line, e.col - 1)
    call s:Say('Changed only the first place (the others take what is typed on that line, in one go)')
    return
  endif
  let typed = strpart(now, e.col - 1, added)
  let first = e.pos[0]
  " bottom to top, right to left: the places not done yet keep their columns
  for [l, c] in reverse(e.pos[1 :])
    if l == first[0]
      let c += added - (e.op ==# 'c' ? e.len : 0)
    endif
    let t = getline(l)
    let at = e.op ==# 'a' ? c - 1 + e.len : c - 1
    let new = strpart(t, 0, at) . typed . strpart(t, e.op ==# 'c' ? at + e.len : at)
    undojoin | call setline(l, new)
  endfor
  call s:Say('Changed ' . s:Count(len(e.pos), 'place'))
endfunction

" find and replace in the project (VSCode's Ctrl+Shift+h): the text (the selection or the word under
" the cursor to start with) and its replacement, then every change listed in a window to check:
" dd leaves one out, Enter makes them all, q cancels. The text is found as typed (not a pattern)
" and in the files the search shows; :cdo s/a/b/ is there for patterns.
silent! call prop_type_add('vimzip_replace_old', {'highlight': 'VimzipReplaceOld'})
silent! call prop_type_add('vimzip_replace_new', {'highlight': 'VimzipReplaceNew'})
function! s:Replace(text) abort
  " (inputdialog(): Esc gives its third argument, telling a cancel from an empty answer)
  let find = inputdialog('Replace in the project: ', a:text, "\x01")
  if find ==# "\x01" || find ==# ''
    return
  endif
  let with = inputdialog('Replace "' . find . '" with: ', find, "\x01")
  if with ==# "\x01"
    return
  endif
  redraw
  call s:QuietWrite('wall')
  " (the files the search looks in: hidden ones too, not .git, in order of their paths; long lines
  " shown in part)
  let out = systemlist('rg -n -H --no-heading --color=never --fixed-strings --case-sensitive --hidden --glob "!.git" --sort path -- '
        \ . shellescape(find) . ' .')
  let matches = []
  for l in out
    let m = matchlist(l, '^\(.\{-}\):\(\d\+\):\(.*\)$')
    if !empty(m) && stridx(m[3], find) >= 0
      call add(matches, [substitute(m[1], '^\./', '', ''), str2nr(m[2]), m[3]])
    endif
  endfor
  if empty(matches)
    call s:Say('Not found: ' . find)
    return
  endif
  call s:EditWin()
  execute 'botright' max([8, min([&lines / 2, len(matches) + 2])]) 'new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nowrap nonumber nocursorline signcolumn=no nolist
  setlocal filetype=vimzipreplace
  silent file [Replace]
  let files = len(uniq(sort(map(copy(matches), 'v:val[0]'))))
  let head = printf('Replace "%s" with "%s": %s in %s.  Enter: replace  dd: leave one out  q: cancel',
        \ find, with, s:Count(len(matches), 'line'), s:Count(files, 'file'))
  let b:vimzip_replace = {'find': find, 'with': with, 'head': head}
  call setline(1, head)
  let n = 1
  for [f, l, t] in matches
    let n += 1
    let head = f . ':' . l . ': '
    if len(t) > 300
      " (cut at characters, not bytes: half a Hangul letter showed as junk)
      let pre = strpart(t, 0, stridx(t, find))
      let t = (strchars(pre) > 60 ? '…' . strcharpart(pre, strchars(pre) - 60) : pre) . strpart(t, len(pre))
      let t = strcharpart(t, 0, 300) . '…'
    endif
    " the line as it will be: each match shown crossed out, followed by its replacement
    let parts = split(t, '\V' . escape(find, '\'), 1)
    let shown = head . parts[0]
    let props = []
    for p in parts[1 :]
      call add(props, [len(shown) + 1, len(find), 'vimzip_replace_old'])
      let shown .= find
      call add(props, [len(shown) + 1, len(with), 'vimzip_replace_new'])
      let shown .= with . p
    endfor
    call setline(n, shown)
    for [col, length, type] in props
      if length
        call prop_add(n, col, {'length': length, 'type': type})
      endif
    endfor
  endfor
  call matchadd('VimzipReplaceHead', '\%1l.*')
  call matchadd('Directory', '^\%>1l[^:]\+:\d\+:')
  setlocal nomodified
  call cursor(2, 1)
  nnoremap <buffer> <silent> <CR> :call <SID>ReplaceApply()<CR>
  nnoremap <buffer> <silent> q :close<CR>
  nnoremap <buffer> <silent> <Esc> :close<CR>
endfunction
function! s:ReplaceApply() abort
  let [find, with] = [b:vimzip_replace.find, b:vimzip_replace.with]
  let todo = {}
  " (every line but the header: dd on the header too made the first change the one left out)
  for l in filter(getline(1, '$'), 'v:val !=# b:vimzip_replace.head')
    let m = matchlist(l, '^\(.\{-}\):\(\d\+\): ')
    if !empty(m)
      let todo[m[1]] = add(get(todo, m[1], []), str2nr(m[2]))
    endif
  endfor
  close
  let pat = '\V\C' . escape(find, '\')
  let rep = escape(with, '\&~')
  let [done, files] = [0, 0]
  for [f, lnums] in items(todo)
    let path = fnamemodify(f, ':p')
    let b = bufnr(path)
    let before = done
    if b > 0 && bufloaded(b) && (getbufvar(b, '&modified') || bufwinid(b) > 0)
      " an open file: changed in vim (undo works), and saved
      for l in lnums
        let t = get(getbufline(b, l), 0, '')
        let done += len(split(t, pat, 1)) - 1
        call setbufline(b, l, substitute(t, pat, rep, 'g'))
      endfor
      if bufwinid(b) > 0
        call win_execute(bufwinid(b), 'call s:QuietWrite("update")')
      endif
    else
      " the others on disk (as they are: line endings and encoding kept), then read again if loaded
      let lines = readfile(path, 'b')
      for l in lnums
        if l <= len(lines)
          let done += len(split(lines[l - 1], pat, 1)) - 1
          let lines[l - 1] = substitute(lines[l - 1], pat, rep, 'g')
        endif
      endfor
      if writefile(lines, path, 'b') != 0
        echohl ErrorMsg | echomsg 'Could not write ' . f | echohl None
        continue
      endif
      if b > 0 && bufloaded(b)
        execute 'checktime' b
      endif
    endif
    let files += done > before
  endfor
  call s:Say(printf('Replaced %d in %s', done, s:Count(files, 'file')))
endfunction

nnoremap <silent> <leader>cr :call <SID>Rename()<CR>
nnoremap <silent> <leader>cf :call <SID>Format(0)<CR>
nnoremap <silent> <leader>ca :call <SID>CodeAction()<CR>
nnoremap <silent> <C-.> :call <SID>CodeAction()<CR>
nnoremap <silent> <leader>cp :call <SID>Problems()<CR>
nnoremap <silent> <leader>cb :call <SID>Build()<CR>
nnoremap <silent> <C-S-b> :call <SID>Build()<CR>
nnoremap <silent> <leader>fc :call <SID>Replace(expand('<cword>'))<CR>
xnoremap <silent> <leader>fc <Esc>:call <SID>Replace(<SID>Selection())<CR>
nnoremap <silent> <C-S-h> :call <SID>Replace(expand('<cword>'))<CR>
xnoremap <silent> <C-S-h> <Esc>:call <SID>Replace(<SID>Selection())<CR>
nnoremap <silent> <C-n> :<C-u>call <SID>MultiAdd(0)<CR>
xnoremap <silent> <C-n> <Esc>:call <SID>MultiAdd(1)<CR>
nnoremap <silent> <leader>mc :call <SID>Resolve('current')<CR>
nnoremap <silent> <leader>mi :call <SID>Resolve('incoming')<CR>
nnoremap <silent> <leader>mb :call <SID>Resolve('both')<CR>
nnoremap <silent> ]x :call <SID>NextConflict(0)<CR>
nnoremap <silent> [x :call <SID>NextConflict(1)<CR>

" ─── typing and reading aids ─────────────────────────────────────────────────────────────────────
" brackets and quotes close themselves (VSCode's auto closing pairs): ( gives (), typing ) before a
" ) steps over it, Backspace in () deletes both, Enter in {} opens a line between. Only before a
" blank, the line's end or a closing bracket, and a quote not right after a letter (don't);
" g:vimzip_autopairs = 0 turns it off
let s:pairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'}
" (languages where a quote is not a pair: Rust's lifetimes 'a, Lisp's 'x, prose's apostrophes;
" vim script's comments start with ")
let s:no_pair = {"'": '^\(rust\|lisp\|scheme\|clojure\|racket\|text\|markdown\|gitcommit\|tex\|ocaml\)$',
      \ '"': '^vim$', '`': '^\(c\|cpp\|python\|java\|rust\|lua\|vim\|text\|gitcommit\)$'}
function! s:PairsOn() abort
  " (not in Replace mode, R: each letter there takes the place of one, Backspace gives it back)
  return get(g:, 'vimzip_autopairs', 1) && &buftype ==# '' && !&paste && mode() ==# 'i'
endfunction
function! s:PairOpen(ch) abort
  let line = getline('.')
  let next = line[col('.') - 1]
  " (the whole character before: a byte of a Hangul letter is no letter)
  let prev = matchstr(strpart(line, 0, col('.') - 1), '.$')
  if !s:PairsOn() || (has_key(s:no_pair, a:ch) && &filetype =~# s:no_pair[a:ch]) || next !~# '^\%(\s\|[)\]}>,;:.=]\|\)$'
    return a:ch
  endif
  " (a quote right after a letter or another quote is an apostrophe or a closing one; not after a
  " string's prefix: Python's f'', r'', b'', C's L"", u8"")
  let word = matchstr(strpart(line, 0, col('.') - 1), '\<\k\+$')
  let prefix = &filetype ==# 'python' ? word =~? '^\%([fburt]\|[rb][fbr]\|[fb]r\)$'
        \ : &filetype =~# '^\%(c\|cpp\)$' && word =~# '^\%(L\|u\|U\|u8\)$'
  if a:ch =~# '[''"`]' && prev =~# '\k\|[''"`\\]' && !prefix
    return a:ch
  endif
  return a:ch . s:pairs[a:ch] . "\<C-g>U\<Left>"
endfunction
function! s:PairClose(ch) abort
  return s:PairsOn() && getline('.')[col('.') - 1] ==# a:ch ? "\<C-g>U\<Right>" : a:ch
endfunction
function! s:PairQuote(ch) abort
  return s:PairsOn() && getline('.')[col('.') - 1] ==# a:ch ? "\<C-g>U\<Right>" : s:PairOpen(a:ch)
endfunction
function! s:PairBS() abort
  let line = getline('.')
  let c = col('.')
  return s:PairsOn() && c > 1 && get(s:pairs, line[c - 2], '-') ==# line[c - 1] ? "\<BS>\<Del>" : "\<BS>"
endfunction
function! s:PairCR() abort
  if pumvisible()
    return "\<CR>"
  endif
  let line = getline('.')
  let c = col('.')
  return s:PairsOn() && c > 1 && line[c - 2 : c - 1] =~# '^\%({}\|\[\]\|()\)$' ? "\<CR>\<C-o>O" : "\<CR>"
endfunction
for [s:o, s:c] in [['(', ')'], ['[', ']'], ['{', '}']]
  execute 'inoremap <expr> <silent>' s:o '<SID>PairOpen("' . s:o . '")'
  execute 'inoremap <expr> <silent>' s:c '<SID>PairClose("' . s:c . '")'
endfor
inoremap <expr> <silent> " <SID>PairQuote('"')
inoremap <expr> <silent> ' <SID>PairQuote("'")
inoremap <expr> <silent> ` <SID>PairQuote('`')
inoremap <expr> <silent> <BS> <SID>PairBS()
inoremap <expr> <silent> <CR> <SID>PairCR()

" the word under the cursor marked where else it is in view (VSCode's occurrence highlight), once
" the cursor rests on it; g:vimzip_word_highlight = 0 turns it off
function! s:WordMark() abort
  let word = &buftype ==# '' && mode() ==# 'n' && get(g:, 'vimzip_word_highlight', 1) ? expand('<cword>') : ''
  " (a name, under the cursor: not the next word on the line, not a number or punctuation)
  if word !~# '^\k\+$' || word =~# '^[0-9_]\+$' || matchstr(getline('.'), '\%' . col('.') . 'c.') !~# '\k'
    let word = ''
  endif
  " (nor a keyword: every int or return lit up)
  if word !=# '' && synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
        \ =~# '^\(Statement\|Keyword\|Type\|Conditional\|Repeat\|StorageClass\|Structure\|Typedef\|PreProc\|Include\|Define\|Macro\|PreCondit\|Boolean\|Operator\|Label\|Exception\|Comment\|String\)$'
    let word = ''
  endif
  if word ==# get(w:, 'vimzip_word', '')
    return
  endif
  call s:WordUnmark()
  if word !=# ''
    let w:vimzip_word = word
    let w:vimzip_word_match = matchadd('VimzipWord', '\V\C\<' . escape(word, '\') . '\>', -1)
  endif
endfunction
function! s:WordUnmark() abort
  if exists('w:vimzip_word_match')
    silent! call matchdelete(w:vimzip_word_match)
    unlet w:vimzip_word_match
  endif
  let w:vimzip_word = ''
endfunction
augroup vimzip_word
  autocmd!
  autocmd CursorHold * call s:WordMark()
  autocmd CursorMoved * if get(w:, 'vimzip_word', '') !=# '' && expand('<cword>') !=# w:vimzip_word | call s:WordUnmark() | endif
  autocmd InsertEnter,WinLeave * if get(w:, 'vimzip_word', '') !=# '' | call s:WordUnmark() | endif
augroup END

" indent guides: a thin line at each indent level, of the file's own width (VSCode's), drawn by vim
" for the leading spaces and tabs; g:vimzip_indent_guides = 0 turns them off
function! s:Guides() abort
  " (the tree has its own)
  if &filetype ==# 'nerdtree'
    return
  endif
  if !get(g:, 'vimzip_indent_guides', 1) || &buftype !=# '' || exists('b:vimzip_view')
    setlocal nolist
    return
  endif
  let w = max([1, shiftwidth()])
  " (the tabs inside a line, aligning names, stay blank: only the leading ones are indent)
  try
    let &l:listchars = 'tab:  ,leadtab:│ ,nbsp:␣,leadmultispace:│' . repeat(' ', w - 1)
  catch /E474/
    let &l:listchars = 'tab:│ ,nbsp:␣,leadmultispace:│' . repeat(' ', w - 1)
  endtry
  setlocal list
endfunction
augroup vimzip_guides
  autocmd!
  autocmd BufWinEnter,FileType * call s:Guides()
  autocmd OptionSet shiftwidth,tabstop,expandtab if &buftype ==# '' | call s:Guides() | endif
augroup END

" brackets colored by depth (VSCode's bracket pair colorization), in the lines in view
" (a bracket in a string or comment does not count: asked of the syntax only when the line has a
" quote or comment mark before it, which is 10 times faster)
function! s:InText(...) abort
  let [l, c] = a:0 ? a:000 : [line('.'), col('.')]
  return getline(l)[: c - 2] =~# '["''`#]\|//\|/\*\|--\|^\s*\*'
        \ && synIDattr(synID(l, c, 0), 'name') =~? 'string\|comment\|character\|regex'
endfunction
function! s:Brackets(...) abort
  let w = a:0 ? a:1 : win_getid()
  let b = winbufnr(w)
  if !get(g:, 'vimzip_bracket_colors', 1) || getbufvar(b, '&buftype') !=# '' || !empty(getbufvar(b, 'vimzip_view'))
        \ || getbufvar(b, '&filetype') =~# '^\(text\|markdown\|gitcommit\|help\|\)$'
    call s:BracketsClear(w)
    call setwinvar(w, 'vimzip_brackets_key', [])
    return
  endif
  call win_execute(w, 'call s:BracketsHere()')
endfunction
function! s:BracketsClear(w) abort
  for id in getwinvar(a:w, 'vimzip_brackets', [])
    silent! call matchdelete(id, a:w)
  endfor
  call setwinvar(a:w, 'vimzip_brackets', [])
endfunction
function! s:BracketsHere() abort
  let [top, bot] = [line('w0'), line('w$')]
  " (nothing changed in view: as it is)
  let key = [bufnr(''), top, bot, b:changedtick]
  if get(w:, 'vimzip_brackets_key', []) ==# key && !empty(get(w:, 'vimzip_brackets', []))
    return
  endif
  let w:vimzip_brackets_key = key
  call s:BracketsClear(win_getid())
  let skip = 's:InText()'
  " the depth at the top of the view: the brackets open around it
  let view = winsaveview()
  call cursor(top, 1)
  let depth = 0
  let start = reltime()
  " (without asking the syntax: a bracket in a string up there shifts the colors at worst)
  while depth < 30 && reltimefloat(reltime(start)) < 0.02 && searchpair('[([{]', '', '[)\]}]', 'bW', '', 0, 10) > 0
    let depth += 1
    " (one on a line that is not indented opens a definition: nothing around it to look for, which
    " would scan the whole file above)
    if indent('.') == 0
      break
    endif
  endwhile
  call winrestview(view)
  let groups = [[], [], []]
  for l in range(top, bot)
    let t = getline(l)
    if len(t) > 1000 || t !~# '[()[\]{}]'
      continue
    endif
    let at = match(t, '[()[\]{}]')
    while at >= 0
      let ch = t[at]
      if !s:InText(l, at + 1)
        if ch =~# '[([{]'
          call add(groups[depth % 3], [l, at + 1])
          let depth += 1
        else
          let depth = max([0, depth - 1])
          call add(groups[depth % 3], [l, at + 1])
        endif
      endif
      let at = match(t, '[()[\]{}]', at + 1)
    endwhile
  endfor
  let ids = []
  for i in range(3)
    for n in range(0, len(groups[i]) - 1, 8)
      call add(ids, matchaddpos('VimzipBracket' . (i + 1), groups[i][n : n + 7], -1))
    endfor
  endfor
  let w:vimzip_brackets = ids
endfunction

" sticky scroll: the lines that open the function, class or block the top of the window is in, kept
" over it while scrolling (VSCode's); g:vimzip_sticky = 0 turns it off
let s:sticky = {}
function! s:StickyHeads(w) abort
  let b = winbufnr(a:w)
  let top = line('w0', a:w)
  if top <= 1
    return []
  endif
  let heads = []
  if getbufvar(b, '&filetype') =~# '^\(text\|markdown\|gitcommit\|help\|\)$'
    return []
  elseif getbufvar(b, '&filetype') ==# 'python'
    " (by indent: the def / class lines above with less of it; a blank line at the top has none,
    " the sticky lines went away on each one in a function, so the next line's)
    let ind = indent(nextnonblank(top) ? nextnonblank(top) : top)
    let l = top - 1
    while l > 0 && len(heads) < 3
      let t = getbufline(b, l)[0]
      if t =~# '\S' && indent(l) < ind
        let ind = indent(l)
        if t =~# '^\s*\%(async\s\+\)\=\%(def\|class\)\>'
          call insert(heads, l)
        endif
      endif
      let l -= 1
    endwhile
    return heads
  endif
  let skip = 's:InText()'
  let view = winsaveview()
  call cursor(top, 1)
  while len(heads) < 3 && searchpair('{', '', '}', 'bW', skip, 0, 20) > 0
    let l = line('.')
    " the head: this line, or the one before when the { stands alone (K&R and Allman alike)
    if getline(l) =~# '^\s*{' && l > 1
      let l = prevnonblank(l - 1)
    endif
    if l < top && index(heads, l) < 0
      call insert(heads, l)
    endif
    if indent(l) == 0
      break
    endif
  endwhile
  call winrestview(view)
  " (only what is out of view: each head line covers one at the top)
  return filter(heads, 'v:val < top + v:key')
endfunction
function! s:Untab(text, ts) abort
  let parts = split(a:text, '\t', 1)
  let out = ''
  for part in parts[: -2]
    let out .= part
    let out .= repeat(' ', a:ts - strdisplaywidth(out) % a:ts)
  endfor
  return out . parts[-1]
endfunction
function! s:Sticky(...) abort
  let w = a:0 ? a:1 : win_getid()
  let b = winbufnr(w)
  let ok = get(g:, 'vimzip_sticky', 1) && getbufvar(b, '&buftype') ==# '' && empty(getbufvar(b, 'vimzip_view'))
        \ && win_gettype(w) ==# '' && !getwinvar(w, '&diff') && winheight(w) > 10
  let heads = []
  if ok
    call win_execute(w, 'let s:sticky_heads = s:StickyHeads(' . w . ')')
    " (never over the cursor: with a small 'scrolloff' it can be on the window's first rows)
    let room = line('.', w) - line('w0', w)
    let heads = room > 0 ? s:sticky_heads[: room - 1] : []
  endif
  let id = get(s:sticky, w, 0)
  if empty(heads)
    if id
      call popup_close(id)
      call remove(s:sticky, w)
    endif
    return
  endif
  let nw = getwinvar(w, '&number') ? max([getwinvar(w, '&numberwidth'), len(line('$', w)) + 1]) : 0
  let sign = getwinvar(w, '&signcolumn') ==# 'no' ? 0 : 2
  " (tabs laid out from the text's start, as in the window: after the line number they shifted)
  let ts = getbufvar(b, '&tabstop')
  let lines = map(copy(heads), {_, l -> repeat(' ', sign) . (nw ? printf('%*d ', nw - 1, l) : '') . s:Untab(getbufline(b, l)[0], ts)})
  let [row, col] = win_screenpos(w)
  let opts = {'line': row, 'col': col, 'minwidth': winwidth(w) - 1, 'maxwidth': winwidth(w) - 1,
        \ 'highlight': 'VimzipSticky', 'zindex': 40, 'wrap': 0}
  if id && !empty(popup_getpos(id))
    call popup_settext(id, lines)
    call popup_setoptions(id, opts)
  else
    let id = popup_create(lines, opts)
    let s:sticky[w] = id
  endif
  let s:sticky_at = filter(get(s:, 'sticky_at', {}), 'index(values(s:sticky), str2nr(v:key)) >= 0')
  let s:sticky_at[id] = [w, heads]
  " (colored as the file is)
  if getbufvar(winbufnr(id), '&syntax') !=# getbufvar(b, '&syntax')
    call setbufvar(winbufnr(id), '&syntax', getbufvar(b, '&syntax'))
  endif
  call setwinvar(id, '&tabstop', getbufvar(b, '&tabstop'))
  call setwinvar(id, 'vimzip_sticky', 1)
endfunction
" the brackets' colors and the sticky lines follow scrolling and editing, a moment later (the
" mouse wheel scrolls in many small steps)
let s:view_pending = {}
function! s:ViewLater(wins) abort
  for w in a:wins
    let s:view_pending[w] = 1
  endfor
  if get(s:, 'view_timer', -1) < 0
    let s:view_timer = timer_start(40, {-> s:ViewNow()})
  endif
endfunction
function! s:ViewNow() abort
  let s:view_timer = -1
  let wins = map(keys(s:view_pending), 'str2nr(v:val)')
  let s:view_pending = {}
  let here = gettabinfo(tabpagenr())[0].windows
  for w in wins
    if index(here, w) >= 0
      call s:Brackets(w)
      call s:Sticky(w)
    endif
  endfor
  " (a window that is gone: its lines too; one on another tab page keeps them for coming back, a
  " popup there cannot be closed from here, and a new one each time piled up)
  for w in keys(s:sticky)
    if win_id2tabwin(str2nr(w)) == [0, 0]
      call popup_close(remove(s:sticky, w))
    endif
  endfor
endfunction
" (vimzip_scroll: vimzip_view is the picture viewer's, which this group's autocmd! emptied)
augroup vimzip_scroll
  autocmd!
  autocmd WinScrolled * call s:ViewLater(map(filter(keys(v:event), 'v:val =~# "^\\d\\+$"'), 'str2nr(v:val)'))
  autocmd BufWinEnter,TextChanged,TextChangedI,InsertLeave,Syntax * call s:ViewLater([win_getid()])
  autocmd WinResized,VimResized,TabEnter,WinClosed * call s:ViewLater(gettabinfo(tabpagenr())[0].windows)
  " (the cursor near the top: the sticky lines make room for it, or take it back)
  autocmd CursorMoved * if line('.') - line('w0') <= 3 && &buftype ==# '' | call s:ViewLater([win_getid()]) | endif
augroup END

" the mouse resting on code: the problem there or the language server's hover in a popup
let g:ale_set_balloons = 1
if has('balloon_eval_term')
  set balloonevalterm balloondelay=500
endif

" ─── code: peek, symbols ─────────────────────────────────────────────────────────────────────────
" a request to this buffer's language server (through ALE's connection), the answer to Callback
let s:lsp_waiting = {}
function! s:LspAsk(capability, Message, Callback) abort
  for linter in exists('g:loaded_ale') ? ale#lsp_linter#GetEnabled(bufnr('')) : []
    if linter.lsp !=# 'tsserver'
      call ale#lsp_linter#StartLSP(bufnr(''), linter, function('s:LspReady', [a:capability, a:Message, a:Callback]))
      return 1
    endif
  endfor
  return 0
endfunction
function! s:LspReady(capability, Message, Callback, linter, details) abort
  let id = a:details.connection_id
  if !ale#lsp#HasCapability(id, a:capability)
    call a:Callback(v:null)
    return
  endif
  call ale#lsp#NotifyForChanges(id, a:details.buffer)
  call ale#lsp#RegisterCallback(id, function('s:LspAnswer'))
  let s:lsp_waiting[ale#lsp#Send(id, a:Message(a:details.buffer))] = a:Callback
endfunction
function! s:LspAnswer(conn_id, response) abort
  if has_key(a:response, 'id') && has_key(s:lsp_waiting, a:response.id)
    call call(remove(s:lsp_waiting, a:response.id), [get(a:response, 'result', v:null)])
  endif
endfunction

" Alt+F12 / Space cd: the definition in a popup at the cursor, without leaving (VSCode's Peek):
" j / k scroll, Enter goes there, Esc closes
function! s:Peek() abort
  let w = expand('<cword>')
  if w ==# ''
    return
  endif
  let [l, c] = [line('.'), min([col('.'), len(getline('.'))])]
  if s:LspHere() && s:LspAsk('definition', {b -> ale#lsp#message#Definition(b, l, c)}, function('s:PeekLsp', [w]))
    return
  endif
  " (no server: the tags, the system headers' too)
  let tags = taglist('^' . w . '$')
  if empty(tags) && &filetype =~# '^\(c\|cpp\)$' && s:SysTags()
    let tags = taglist('^' . w . '$')
  endif
  if empty(tags)
    call s:Say('No definition found: ' . w, 'WarningMsg')
    return
  endif
  let t = tags[0]
  let file = fnamemodify(t.filename, ':p')
  let lines = s:PeekLines(file)
  let lnum = t.cmd =~# '^\d\+$' ? str2nr(t.cmd) : 0
  if !lnum
    " (a /^text$/ search: found as text)
    let text = substitute(substitute(t.cmd, '^/\^\=\|\$\=/;\="\=$', '', 'g'), '\\\([/\\]\)', '\1', 'g')
    let lnum = index(lines, text) + 1
    let lnum = lnum ? lnum : match(lines, '\V\<' . escape(w, '\') . '\>') + 1
  endif
  call s:PeekShow(file, max([1, lnum]), lines)
endfunction
function! s:PeekLines(file) abort
  let b = bufnr(a:file)
  return b > 0 && bufloaded(b) ? getbufline(b, 1, '$') : filereadable(a:file) ? readfile(a:file) : []
endfunction
function! s:PeekLsp(word, result) abort
  let items = type(a:result) == v:t_dict ? [a:result] : type(a:result) == v:t_list ? a:result : []
  if empty(items)
    call s:Say('No definition found: ' . a:word, 'WarningMsg')
    return
  endif
  let i = items[0]
  let uri = get(i, 'targetUri', get(i, 'uri', ''))
  let range = get(i, 'targetSelectionRange', get(i, 'range', get(i, 'targetRange', {})))
  let file = ale#util#ToResource(uri)
  call s:PeekShow(file, get(get(range, 'start', {}), 'line', 0) + 1, s:PeekLines(file))
endfunction
function! s:PeekShow(file, lnum, lines) abort
  if empty(a:lines)
    return
  endif
  " (from a line or two above, for the comment before it)
  let first = max([1, a:lnum - 2])
  let shown = a:lines[first - 1 : first + 199]
  let height = min([15, len(shown), &lines - 6])
  let s:peek = {'file': a:file, 'lnum': a:lnum}
  let id = popup_atcursor(shown, {'title': ' ' . fnamemodify(a:file, ':~:.') . ':' . a:lnum . '  Enter: go there (Ctrl+v beside, Ctrl+x below)  Esc: close ',
        \ 'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1],
        \ 'maxheight': height, 'minheight': height, 'minwidth': min([80, &columns - 10]), 'maxwidth': &columns - 10,
        \ 'scrollbar': 1, 'moved': 'any', 'filter': function('s:PeekKey'), 'firstline': 1})
  let ft = getbufvar(bufnr(a:file), '&filetype')
  let ft = ft !=# '' ? ft : &filetype
  call setbufvar(winbufnr(id), '&syntax', ft)
  call setwinvar(id, '&tabstop', &tabstop)
  " (the definition's line marked)
  call matchaddpos('VimzipPeekLine', [a:lnum - first + 1], 10, -1, {'window': id})
endfunction
function! s:PeekKey(id, key) abort
  let top = popup_getoptions(a:id).firstline
  let n = line('$', a:id)
  let steps = {'j': 1, "\<Down>": 1, 'k': -1, "\<Up>": -1, "\<C-d>": 7, "\<C-u>": -7, "\<C-f>": 14, "\<C-b>": -14,
        \ "\<ScrollWheelDown>": 3, "\<ScrollWheelUp>": -3}
  if has_key(steps, a:key)
    call popup_setoptions(a:id, {'firstline': max([1, min([n, top + steps[a:key]])])})
    return 1
  elseif a:key ==# "\<CR>" || a:key ==# "\<C-v>" || a:key ==# "\<C-x>"
    call popup_close(a:id)
    " (from a panel, the terminal's or a list's: in the editor, not over the panel)
    if &buftype !=# ''
      call s:EditWin()
    endif
    normal! m'
    execute (a:key ==# "\<C-v>" ? 'vsplit' : a:key ==# "\<C-x>" ? 'split' : 'edit') fnameescape(fnamemodify(s:peek.file, ':~:.'))
    call cursor(s:peek.lnum, 1)
    normal! zz
    return 1
  elseif a:key ==# "\<Esc>" || a:key ==# 'q'
    call popup_close(a:id)
    return 1
  endif
  return 0
endfunction

" Space fS: the project's symbols as the language server knows them (VSCode's Ctrl+T; vim's Ctrl+t
" stays the way back from a tag), asked for a name, then picked from a list; Space ft lists the tags
let s:symbol_kinds = {1: 'file', 2: 'module', 3: 'namespace', 4: 'package', 5: 'class', 6: 'method',
      \ 7: 'property', 8: 'field', 9: 'constructor', 10: 'enum', 11: 'interface', 12: 'function',
      \ 13: 'variable', 14: 'constant', 22: 'enum member', 23: 'struct', 24: 'event', 25: 'operator',
      \ 26: 'type parameter'}
function! s:Symbols() abort
  if !s:LspHere()
    call s:Buf('Tags')
    return
  endif
  let q = inputdialog('Symbol in the project (language server): ', '', "\x01")
  if q ==# "\x01" || q ==# ''
    return
  endif
  if !s:LspAsk('symbol_search', {b -> ale#lsp#message#Symbol(q)}, function('s:SymbolsGot', [q]))
    call s:Buf('Tags')
  endif
endfunction
function! s:SymbolsGot(query, result) abort
  let items = type(a:result) == v:t_list ? a:result : []
  if empty(items)
    call s:Say('No symbols found: ' . a:query . ' (the server may still be reading the project)', 'WarningMsg')
    return
  endif
  let rows = []
  for i in items
    let loc = get(i, 'location', {})
    let file = fnamemodify(ale#util#ToResource(get(loc, 'uri', '')), ':~:.')
    let line = get(get(get(loc, 'range', {}), 'start', {}), 'line', 0) + 1
    call add(rows, printf("%s\t%s\t%s\t%s:%d", i.name, get(s:symbol_kinds, get(i, 'kind', 0), ''),
          \ get(i, 'containerName', ''), file, line))
  endfor
  call s:EditWin()
  call fzf#run(fzf#wrap({'source': rows, 'sink*': function('s:SymbolPicked'),
        \ 'options': ['--prompt', 'Symbol> ', '--delimiter', "\t", '--tabstop', '4', '--query', a:query,
        \   '--expect', 'ctrl-v,ctrl-x', '--header', 'Enter open   Ctrl+v beside   Ctrl+x below   (symbol, kind, in, where)']}))
endfunction
function! s:SymbolPicked(lines) abort
  let [key, row] = [get(a:lines, 0, ''), get(a:lines, 1, '')]
  let m = matchlist(row, '\t\([^\t]*\):\(\d\+\)$')
  if !empty(m)
    normal! m'
    execute get({'ctrl-v': 'vsplit', 'ctrl-x': 'split'}, key, 'edit') fnameescape(expand(m[1]))
    call cursor(str2nr(m[2]), 1)
    normal! zz
  endif
endfunction

" ─── git: branches, push, pull ───────────────────────────────────────────────────────────────────
" Space go, or a click on the branch in the status bar: switch branch (a new name typed: a new
" branch from here); Space gP pushes, Space gF pulls, in a panel that closes itself when it went
" well (and stays to show why, or to ask for a password)
function! s:Branches() abort
  if !s:InGit()
    return
  endif
  let git = 'git -C ' . shellescape(getcwd())
  let current = trim(system(git . ' branch --show-current'))
  let rows = systemlist(git . ' for-each-ref --sort=-committerdate --format=' . shellescape('%(refname:short)%09%(committerdate:relative)%09%(subject)') . ' refs/heads refs/remotes')
  call filter(rows, 'v:val !~# "^[^\t]*/HEAD\t" && v:val !~# "^origin\t"')
  call map(rows, '(split(v:val, "\t")[0] ==# current ? "* " : "  ") . v:val')
  call fzf#run(fzf#wrap({'source': rows, 'sink*': function('s:BranchPicked'),
        \ 'options': ['--prompt', 'Branch> ', '--delimiter', "\t", '--tabstop', '2', '--print-query',
        \   '--bind', 'enter:accept-or-print-query',
        \   '--header', 'Enter switch (a new name typed: a new branch)   on ' . current]}))
endfunction
function! s:BranchPicked(lines) abort
  let [query, picked] = [trim(get(a:lines, 0, '')), get(a:lines, 1, '')]
  let git = 'git -C ' . shellescape(getcwd())
  " (changes typed just now saved first: the files are read again from the new branch)
  call s:QuietWrite('wall')
  if picked !=# ''
    let name = trim(split(picked[2 :], "\t")[0])
    " (a remote's branch: a local one following it, as VSCode does)
    let local = substitute(name, '^[^/]\+/', '', '')
    if name !=# local && system(git . ' rev-parse --verify --quiet refs/remotes/' . shellescape(name)) !=# ''
      let has_local = system(git . ' rev-parse --verify --quiet refs/heads/' . shellescape(local)) !=# ''
      let out = system(git . ' switch ' . (has_local ? shellescape(local) : '--track ' . shellescape(name)))
    else
      let out = system(git . ' switch ' . shellescape(name))
    endif
  elseif query !=# ''
    let out = system(git . ' switch -c ' . shellescape(query))
  else
    return
  endif
  if v:shell_error
    call s:Say('Not switched: ' . get(filter(split(out, "\n"), 'v:val =~# "error\\|fatal\\|\\S"'), 0, out), 'WarningMsg')
    return
  endif
  call s:GitAfter()
  call s:Say('On ' . trim(system(git . ' branch --show-current')))
endfunction
" files, signs and the tree as the new branch has them
function! s:GitAfter() abort
  silent! checktime
  if exists('g:loaded_gitgutter') && g:gitgutter_enabled
    call gitgutter#all(1)
  endif
  call s:TreeSync()
  call s:BarRefresh()
endfunction
function! s:GitPanel(what) abort
  if !s:InGit()
    return
  endif
  " (one panel: the last one's, failed or still asking, closed first)
  if bufexists(get(s:, 'git_panel', -1))
    if term_getstatus(s:git_panel) =~# 'running'
      call s:Say('git is still running in the panel below')
      return
    endif
    execute 'silent! bwipeout!' s:git_panel
  endif
  let git = 'git -C ' . shellescape(getcwd())
  if a:what ==# 'push'
    " (a branch the remote does not have yet: pushed and followed, as VSCode's Publish Branch)
    call system(git . ' rev-parse --abbrev-ref --symbolic-full-name @{u}')
    let cmd = v:shell_error ? 'git push -u origin HEAD' : 'git push'
  else
    let cmd = 'git pull'
  endif
  call s:QuietWrite('wall')
  call s:EditWin()
  let from = win_getid()
  execute 'botright' max([6, min([10, s:PanelSize('term')])]) 'new'
  let blank = bufnr('')
  let buf = term_start([&shell, &shellcmdflag, cmd], {'curwin': 1, 'term_name': 'Git: ' . cmd, 'term_kill': 'hup',
        \ 'exit_cb': {_, status -> timer_start(200, {-> s:GitPanelDone(buf, cmd, status)})}})
  if bufexists(blank) && blank != buf
    execute 'silent! bwipeout' blank
  endif
  setlocal winfixheight nonumber nocursorline signcolumn=no nolist
  nnoremap <buffer> <silent> q :close<CR>
  call setbufvar(buf, '&buflisted', 0)
  let s:git_panel = buf
  " (focus stays with the files, unless git has a question: a user name, password or passphrase,
  " typed into the panel)
  call win_gotoid(from)
  call s:Layout()
  call timer_start(300, function('s:GitPanelAsks', [buf]), {'repeat': -1})
endfunction
function! s:GitPanelAsks(buf, timer) abort
  if !bufexists(a:buf) || term_getstatus(a:buf) !~# 'running'
    call timer_stop(a:timer)
    return
  endif
  let last = get(filter(getbufline(a:buf, 1, '$'), 'v:val =~# "\\S"'), -1, '')
  if last =~? '\(username\|password\|passphrase\|token\|yes/no\|(y/n)\|PIN\).*[:?]\s*$' && bufwinid(a:buf) > 0
    call timer_stop(a:timer)
    call win_gotoid(bufwinid(a:buf))
    call s:Say('git asks: type the answer in the panel')
  endif
endfunction
function! s:GitPanelDone(buf, cmd, status) abort
  if a:status == 0 && bufexists(a:buf)
    execute 'silent! bwipeout!' a:buf
    call s:Layout()
  endif
  call s:GitAfter()
  if a:status == 0
    call s:Say(a:cmd =~# 'pull' ? 'Pulled' : 'Pushed')
  else
    call s:Say(a:cmd . ' failed: see the panel below', 'WarningMsg')
  endif
endfunction
function! VimzipBranchClick(info) abort
  if a:info.button ==# 'l'
    call s:Branches()
  endif
  return 0
endfunction

" ─── Markdown preview ────────────────────────────────────────────────────────────────────────────
" Ctrl+Shift+v / Space cv in a Markdown file: the text as it reads, beside it (VSCode's preview):
" headings, lists, quotes, code, tables and links laid out, marks hidden; it follows the typing and
" the cursor
silent! call prop_type_add('vimzip_md_bold', {'highlight': 'VimzipMdBold'})
silent! call prop_type_add('vimzip_md_italic', {'highlight': 'VimzipMdItalic'})
silent! call prop_type_add('vimzip_md_code', {'highlight': 'VimzipMdCode'})
silent! call prop_type_add('vimzip_md_link', {'highlight': 'VimzipMdLink'})
silent! call prop_type_add('vimzip_md_h1', {'highlight': 'VimzipMdH1'})
silent! call prop_type_add('vimzip_md_h2', {'highlight': 'VimzipMdH2'})
silent! call prop_type_add('vimzip_md_dim', {'highlight': 'VimzipMdDim'})
silent! call prop_type_add('vimzip_md_block', {'highlight': 'VimzipMdBlock'})
" a line's inline marks: [text without them, [[col, len, type], ...]]
function! s:MdInline(text) abort
  let out = ''
  let props = []
  let t = a:text
  while t !=# ''
    let m = matchlist(t, '^\(`\+\)\(.\{-}\)\1')
    if !empty(m)
      call add(props, [len(out) + 1, len(m[2]), 'vimzip_md_code'])
      let out .= m[2]
      let t = t[len(m[0]) :]
      continue
    endif
    " (\* is a *: a mark taken as text)
    let m = matchlist(t, '^\\\([[:punct:]]\)')
    if !empty(m)
      let out .= m[1]
      let t = t[2 :]
      continue
    endif
    " (a link's text may be a picture: a README's badges, [![CI](badge.svg)](actions))
    let m = matchlist(t, '^!\=\[\(\%(!\[[^\]]*\]([^)]*)\|[^\]]\)*\)\](\([^)]*\))')
    if !empty(m)
      if t[0] ==# '!'
        let [label, lp] = ['▣ ' . (m[1] !=# '' ? m[1] : fnamemodify(m[2], ':t')), []]
      else
        let [label, lp] = s:MdInline(m[1])
      endif
      call add(props, [len(out) + 1, len(label), 'vimzip_md_link'])
      call extend(props, map(lp, '[v:val[0] + len(out), v:val[1], v:val[2]]'))
      let out .= label
      let t = t[len(m[0]) :]
      continue
    endif
    let m = matchlist(t, '^\(\*\*\|__\)\(\S.\{-}\)\1')
    if !empty(m)
      let [inner, ip] = s:MdInline(m[2])
      call add(props, [len(out) + 1, len(inner), 'vimzip_md_bold'])
      call extend(props, map(ip, '[v:val[0] + len(out), v:val[1], v:val[2]]'))
      let out .= inner
      let t = t[len(m[0]) :]
      continue
    endif
    " (* also inside a word, as Markdown has it; _ not: snake_case_names)
    let m = matchlist(t, '^\(\*\)\(\S.\{-}\S\|\S\)\*')
    if empty(m)
      let m = matchlist(t, '^\(_\)\(\S.\{-}\)_\%(\w\)\@!')
      let m = !empty(m) && (out ==# '' || out[-1:] !~# '\w') ? m : []
    endif
    if !empty(m)
      let [inner, ip] = s:MdInline(m[2])
      call add(props, [len(out) + 1, len(inner), 'vimzip_md_italic'])
      call extend(props, map(ip, '[v:val[0] + len(out), v:val[1], v:val[2]]'))
      let out .= inner
      let t = t[len(m[0]) :]
      continue
    endif
    let m = matchlist(t, '^<\(https\=://[^>]*\)>')
    if !empty(m)
      call add(props, [len(out) + 1, len(m[1]), 'vimzip_md_link'])
      let out .= m[1]
      let t = t[len(m[0]) :]
      continue
    endif
    " (plain text up to the next possible mark)
    let n = match(t, '[`!\[*_<\\]', 1)
    let n = n < 0 ? len(t) : n
    let out .= t[: n - 1]
    let t = t[n :]
  endwhile
  return [out, props]
endfunction
" does this line end the paragraph before it (or the quote's, inside one)?
function! s:MdStops(line, quote) abort
  let l = a:line
  if a:quote
    " (a quote goes on while its lines start with as many >)
    return l !~# '^\s*' . repeat('>', a:quote) . '\%(>\)\@!' || l =~# '^\s*>\+\s*$'
  endif
  return l !~# '\S' || l =~# '^\s\{,3}\%(#\{1,6}\%(\s\|$\)\|```\|\~\~\~\|>\|[-*+]\s\|\d\{1,9}[.)]\s\||\)'
        \ || l =~# '^\s\{,3}\([-*_]\)\%(\s*\1\)\{2,}\s*$' && l !~# '^\s\{,3}-\+\s*$'
endfunction
" a paragraph's text in lines of at most width cells, broken at blanks; its marks follow it
function! s:MdWrap(text, props, width) abort
  let out = []
  let [start, n] = [0, len(a:text)]
  while start < n
    let rest = strpart(a:text, start)
    if strwidth(rest) <= a:width
      let end = n
    else
      " the last blank that keeps the line within the width (a longer word: on a line of its own)
      let cut = strpart(rest, 0, len(strcharpart(rest, 0, a:width + 1)))
      let b = match(cut, '.*\zs ')
      let sp = match(rest, ' ', 1)
      let end = start + (b > 0 ? b : sp > 0 ? sp : len(rest))
    endif
    let lp = []
    for [col, length, type] in a:props
      let [s0, e0] = [max([col - 1, start]), min([col - 1 + length, end])]
      if e0 > s0
        call add(lp, [s0 - start + 1, e0 - s0, type])
      endif
    endfor
    call add(out, [strpart(a:text, start, end - start), lp])
    let start = end
    while start < n && a:text[start] ==# ' '
      let start += 1
    endwhile
  endwhile
  return empty(out) ? [['', []]] : out
endfunction
" the preview's lines, their marks, and for each source line the preview line it begins
function! s:MdRender(src, ...) abort
  let [lines, props, map] = [[], [], []]
  let s:md_in_code = -2
  let i = 0
  let n = len(a:src)
  let width = get(a:, 1, 60)
  while i < n
    let t = a:src[i]
    call add(map, len(lines) + 1)
    " fenced code: as it is, on a shaded block
    let fence = matchstr(t, '^\s*\zs\(```\+\|\~\~\~\+\)')
    if fence !=# ''
      let lang = trim(t[stridx(t, fence) + len(fence) :])
      call add(lines, lang !=# '' ? '  ' . lang : '')
      call add(props, [len(lines), 1, max([1, len(lines[-1])]), 'vimzip_md_dim'])
      let i += 1
      while i < n && a:src[i] !~# '^\s*' . fence[0] . '\{' . len(fence) . ',}\s*$'
        call add(map, len(lines) + 1)
        call add(lines, '  ' . a:src[i])
        call add(props, [len(lines), 1, max([1, len(lines[-1])]), 'vimzip_md_block'])
        let i += 1
      endwhile
      call add(map, len(lines) + 1)
      let i += 1
      continue
    endif
    " a table: columns lined up, drawn with lines
    if t =~# '^\s*|.*|\s*$' && i + 1 < n && a:src[i + 1] =~# '^\s*|\=\s*:\=-\+:\=\s*\(|\s*:\=-\+:\=\s*\)*|\=\s*$'
      let rows = []
      let j = i
      while j < n && a:src[j] =~# '^\s*|.*|\s*$'
        if j != i + 1
          call add(rows, map(split(trim(a:src[j])[1 : -2], '\\\@<!|', 1), 'trim(v:val)'))
        endif
        let j += 1
      endwhile
      let cols = max(map(copy(rows), 'len(v:val)'))
      let widths = map(range(cols), {c -> max(map(copy(rows), {_, r -> strwidth(s:MdInline(get(r, c, ''))[0])}))})
      for r in range(len(rows))
        let line = '│'
        for c in range(cols)
          let [cell, cp] = s:MdInline(get(rows[r], c, ''))
          for p in cp
            call add(props, [len(lines) + 1, len(line) + 1 + p[0], p[1], p[2]])
          endfor
          if r == 0
            call add(props, [len(lines) + 1, len(line) + 2, len(cell), 'vimzip_md_bold'])
          endif
          let line .= ' ' . cell . repeat(' ', widths[c] - strwidth(cell)) . ' │'
        endfor
        call add(lines, line)
        if r == 0
          call add(lines, '├' . join(map(copy(widths), 'repeat("─", v:val + 2)'), '┼') . '┤')
          call add(props, [len(lines), 1, len(lines[-1]), 'vimzip_md_dim'])
        endif
      endfor
      for _ in range(i + 1, j - 1)
        call add(map, len(lines))
      endfor
      let i = j
      continue
    endif
    " (closing #s only after a blank: # C# keeps its #)
    let m = matchlist(t, '^\s\{,3}\(#\{1,6}\)\%(\s\+\(.\{-}\)\)\=\%(\s\+#\+\)\=\s*$')
    if !empty(m)
      let [text, tp] = s:MdInline(m[2])
      call add(lines, text)
      call add(props, [len(lines), 1, max([1, len(text)]), len(m[1]) == 1 ? 'vimzip_md_h1' : 'vimzip_md_h2'])
      if len(m[1]) <= 2
        call add(lines, repeat(len(m[1]) == 1 ? '═' : '─', max([strwidth(text), 3])))
        call add(props, [len(lines), 1, len(lines[-1]), 'vimzip_md_dim'])
      endif
      let i += 1
      continue
    endif
    " (a heading underlined, Title / =====, or with ----- under it: not a rule there)
    if t =~# '\S' && t !~# '^\%(\s*\%([-*+]\|\d\+[.)]\)\s\|\s*>\|    \|\t\)' && i + 1 < n
          \ && a:src[i + 1] =~# '^\s\{,3}\%(=\+\|-\+\)\s*$'
      let [text, tp] = s:MdInline(trim(t))
      let one = a:src[i + 1] =~# '='
      call add(lines, text)
      call add(props, [len(lines), 1, max([1, len(text)]), one ? 'vimzip_md_h1' : 'vimzip_md_h2'])
      call add(lines, repeat(one ? '═' : '─', max([strwidth(text), 3])))
      call add(props, [len(lines), 1, len(lines[-1]), 'vimzip_md_dim'])
      call add(map, len(lines))
      let i += 2
      continue
    endif
    if t =~# '^\s\{,3}\([-*_]\)\(\s*\1\)\{2,}\s*$'
      call add(lines, repeat('─', width))
      call add(props, [len(lines), 1, len(lines[-1]), 'vimzip_md_dim'])
      let i += 1
      continue
    endif
    " (a code block indented by four)
    if t =~# '^\(    \|\t\)' && (empty(lines) || lines[-1] ==# '' || get(s:, 'md_in_code', 0) == i - 1)
      call add(lines, t)
      call add(props, [len(lines), 1, len(t), 'vimzip_md_block'])
      let s:md_in_code = i
      let i += 1
      continue
    endif
    " lists, quotes and paragraphs: the lines after joined into one (a line break in the file is a
    " space in Markdown; two spaces or \ at its end break it), then wrapped to the preview's width,
    " a list item's lines under its first letter
    if t !~# '\S'
      call add(lines, '')
      let i += 1
      continue
    endif
    " a picture on a line of its own: drawn
    let im = matchlist(t, '^\s*!\[\([^\]]*\)\](<\=\([^)> ]\+\)>\=\%(\s\+[^)]*\)\=)\s*$')
    let got = !empty(im) && exists('s:md_ctx') ? s:MdImage(im[2]) : []
    if len(got) == 3
      let base = len(lines)
      call extend(lines, got[0])
      for [l, c, length, type] in got[1]
        call add(props, [base + l, c, length, type])
      endfor
      if has_key(got[2], 'data')
        call add(s:md_ctx.pix, extend({'lnum': base + 1}, got[2]))
      elseif has_key(got[2], 'id')
        call add(s:md_ctx.ids, got[2].id)
      endif
      let i += 1
      continue
    endif
    let [lead, next, body, quote] = ['', '', t, 0]
    let m = matchlist(t, '^\(\s*\)\([-*+]\)\s\+\(\[[ xX]\]\s\+\)\=\(.*\)$')
    let o = matchlist(t, '^\(\s*\)\(\d\{1,9}[.)]\)\s\+\(.*\)$')
    if !empty(m)
      let box = m[3] =~? 'x' ? '☑ ' : m[3] !=# '' ? '☐ ' : ''
      let lead = m[1] . (box !=# '' ? box : '• ')
      let body = m[4]
    elseif !empty(o)
      let lead = o[1] . o[2] . ' '
      let body = o[3]
    else
      let q = matchlist(t, '^\(\s*>\+\)\s\=\(.*\)$')
      if !empty(q)
        let quote = len(substitute(q[1], '[^>]', '', 'g'))
        let lead = repeat('▎ ', quote)
        let body = q[2]
      endif
    endif
    let next = quote ? lead : repeat(' ', strwidth(lead))
    let level = 0
    let i += 1
    while i < n && !s:MdStops(a:src[i], quote)
      let c = a:src[i]
      " (Title / =====: the paragraph was a heading)
      if !quote && empty(m) && empty(o) && c =~# '^\s\{,3}\%(=\+\|-\+\)\s*$'
        let level = c =~# '=' ? 1 : 2
        call add(map, len(lines) + 1)
        let i += 1
        break
      endif
      let c = quote ? substitute(c, '^\s*>\+\s\=', '', '') : c
      let body .= (body =~# '\%(  \|\\\)$' ? "\n" : ' ') . substitute(c, '^\s\+', '', '')
      call add(map, len(lines) + 1)
      let i += 1
    endwhile
    let first = len(lines) + 1
    for part in split(body, "\n", 1)
      let [text, tp] = s:MdInline(trim(substitute(part, '\\$', '', ''), ' ', 2))
      for [l, lp] in level ? [[text, tp]] : s:MdWrap(text, tp, max([10, width - strwidth(next)]))
        let pre = len(lines) >= first ? next : lead
        call add(lines, pre . l)
        if pre =~# '▎'
          call add(props, [len(lines), 1, len(pre), 'vimzip_md_dim'])
        endif
        for p in lp
          call add(props, [len(lines), len(pre) + p[0], p[1], p[2]])
        endfor
      endfor
    endfor
    if level
      call add(props, [first, 1, max([1, len(lines[first - 1])]), level == 1 ? 'vimzip_md_h1' : 'vimzip_md_h2'])
      call add(lines, repeat(level == 1 ? '═' : '─', max([strwidth(lines[-1]), 3])))
      call add(props, [len(lines), 1, len(lines[-1]), 'vimzip_md_dim'])
    endif
  endwhile
  return [lines, props, map]
endfunction
function! s:MdPreview() abort
  if &filetype !=# 'markdown'
    call s:Say('Markdown preview: in a Markdown file')
    return
  endif
  let src = bufnr('')
  let old = getbufvar(src, 'vimzip_md_preview', -1)
  if bufwinnr(old) > 0
    execute bufwinnr(old) . 'close'
    return
  endif
  let from = win_getid()
  execute 'rightbelow vertical' max([40, winwidth(0) / 2]) 'new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted wrap linebreak breakindent nonumber
  setlocal nocursorline signcolumn=no nolist nomodeline filetype=vimzipmdpreview
  nnoremap <buffer> <silent> q :close<CR>
  execute 'silent file' fnameescape('Preview ' . fnamemodify(bufname(src), ':t'))
  let b:vimzip_md_source = src
  call setbufvar(src, 'vimzip_md_preview', bufnr(''))
  " (the last preview's pictures were let go with it)
  call setbufvar(src, 'vimzip_md_imgs', {})
  call win_gotoid(from)
  call s:MdUpdate(src)
  augroup vimzip_md
    autocmd! * <buffer>
    autocmd TextChanged,TextChangedI <buffer> call s:MdLater(bufnr(''))
    autocmd CursorMoved,CursorMovedI <buffer> call s:MdFollow(bufnr(''))
    " (and closes with its file)
    autocmd BufUnload,BufDelete <buffer> call s:MdClose(str2nr(expand('<abuf>')))
  augroup END
endfunction
" (wrapped to its width: again when it changes)
augroup vimzip_md_size
  autocmd!
  autocmd WinResized,VimResized * for s:w in gettabinfo(tabpagenr())[0].windows
        \ | if getbufvar(winbufnr(s:w), '&filetype') ==# 'vimzipmdpreview' && getwinvar(s:w, 'vimzip_md_width') != winwidth(s:w)
        \ | call setwinvar(s:w, 'vimzip_md_width', winwidth(s:w)) | call s:MdLater(getbufvar(winbufnr(s:w), 'vimzip_md_source')) | endif | endfor
augroup END
function! s:MdClose(src) abort
  let pv = getbufvar(a:src, 'vimzip_md_preview', -1)
  if bufexists(pv)
    call timer_start(0, {-> bufexists(pv) ? execute('silent! bwipeout ' . pv) : 0})
  endif
endfunction
function! s:MdLater(src) abort
  call timer_stop(getbufvar(a:src, 'vimzip_md_timer', -1))
  call setbufvar(a:src, 'vimzip_md_timer', timer_start(300, {-> s:MdUpdate(a:src)}))
endfunction
function! s:MdUpdate(src) abort
  let pv = getbufvar(a:src, 'vimzip_md_preview', -1)
  if !bufexists(pv)
    return
  endif
  let width = max([20, winwidth(bufwinid(pv)) - 1])
  " (pictures of the file's folder drawn in it, as the image viewer draws them; each once, kept)
  let s:md_ctx = {'src': a:src, 'dir': fnamemodify(bufname(a:src), ':p:h'), 'width': width,
        \ 'kind': s:Pixels(pv), 'cache': getbufvar(a:src, 'vimzip_md_imgs', {}), 'pix': [], 'ids': []}
  call setbufvar(a:src, 'vimzip_md_imgs', s:md_ctx.cache)
  try
    let [lines, props, map] = s:MdRender(getbufline(a:src, 1, '$'), width)
  finally
    let ctx = s:md_ctx
    unlet s:md_ctx
  endtry
  call setbufvar(pv, 'vimzip_pix', ctx.kind ==# 'sixel' ? {'kind': 'sixel', 'items': ctx.pix}
        \ : ctx.kind ==# 'kitty' ? {'kind': 'kitty', 'ids': ctx.ids} : {})
  call setbufvar(pv, '&modifiable', 1)
  silent call deletebufline(pv, 1, '$')
  call setbufline(pv, 1, lines)
  for [l, c, len, type] in props
    if len > 0
      silent! call prop_add(l, c, {'length': len, 'type': type, 'bufnr': pv})
    endif
  endfor
  call setbufvar(pv, '&modifiable', 0)
  call setbufvar(a:src, 'vimzip_md_map', map)
  call s:MdFollow(a:src)
  if !empty(ctx.pix) || s:pix_shown
    call s:PixDraw(1)
  endif
endfunction
" a picture in the preview: [lines, props, sixel] once drawn, else [] and drawn in the background
" (the preview is made again when it is in)
function! s:MdImage(path) abort
  let c = s:md_ctx
  let file = simplify(a:path =~# '^/' ? a:path : c.dir . '/' . a:path)
  if a:path =~# '^\a\+:' || !filereadable(file) || file !~? '\.\(png\|jpe\=g\|gif\|webp\|bmp\|tiff\=\)$'
    return []
  endif
  let size = [max([4, c.width - 2]), max([4, min([24, c.width / 4])])]
  let key = join([file, getftime(file), c.kind] + size, '|')
  let got = get(c.cache, key, 0)
  if type(got) == v:t_list
    return got
  elseif got is 0 && executable(s:view)
    let c.cache[key] = 1
    let out = []
    if c.kind !=# ''
      let cell = s:CellPixels()
      let cmd = [s:view, c.kind, file] + size + cell
    else
      let cmd = [s:view, s:Octants() ? 'cells' : 'image', file] + size + (&termguicolors ? [] : ['256'])
    endif
    let src = c.src
    call job_start(cmd, {'out_cb': {_, l -> add(out, l)}, 'err_cb': {_, l -> add(out, 'error: ' . l)},
          \ 'close_cb': {_ -> s:MdImageDone(src, key, c.kind, size, out)}})
  endif
  return []
endfunction
function! s:MdImageDone(src, key, kind, size, out) abort
  let cache = getbufvar(a:src, 'vimzip_md_imgs', {})
  if empty(a:out) || a:out[0] =~# '^error: ' || len(a:out) < 2
    let cache[a:key] = ['failed']
    return
  endif
  if a:kind ==# ''
    let [rows, props] = s:BlockRows(a:out[1 :], a:size[0])
    let cache[a:key] = [rows, props, {}]
  else
    let [cols, nrows] = map(split(a:out[0])[2 : 3], 'str2nr(v:val)')
    let pad = max([0, (a:size[0] - cols) / 2]) + 1
    if a:kind ==# 'kitty'
      let s:kitty_next = get(s:, 'kitty_next', 0xB000) + 1
      let id = s:kitty_next
      call s:KittySend(id, a:out[1], cols, nrows)
      let name = 'VimzipKitty' . id
      call s:ImgGroup(name, printf('guifg=#%06x', id))
      let rows = map(a:out[2 :], 'repeat(" ", pad) . v:val')
      let cache[a:key] = [rows, map(range(len(rows)), '[v:val + 1, pad + 1, len(rows[v:val]) - pad, name]'), {'id': id}]
    else
      let cache[a:key] = [repeat([''], nrows), [], {'data': a:out[1 :], 'col': pad}]
    endif
  endif
  call s:MdLater(a:src)
endfunction
" the preview scrolled to where the cursor is in the source
function! s:MdFollow(src) abort
  let pv = getbufvar(a:src, 'vimzip_md_preview', -1)
  let w = bufwinid(pv)
  let map = getbufvar(a:src, 'vimzip_md_map', [])
  if w < 0 || empty(map)
    return
  endif
  let l = get(map, line('.') - 1, map[-1])
  call win_execute(w, 'call cursor(' . l . ', 1) | normal! zz')
endfunction

nnoremap <silent> <M-F12> :call <SID>Peek()<CR>
nnoremap <silent> <leader>cd :call <SID>Peek()<CR>
nnoremap <silent> <leader>ft :call <SID>Buf('Tags')<CR>
nnoremap <silent> <leader>fS :call <SID>Symbols()<CR>
nnoremap <silent> <leader>go :call <SID>Branches()<CR>
nnoremap <silent> <leader>gP :call <SID>GitPanel('push')<CR>
nnoremap <silent> <leader>gF :call <SID>GitPanel('pull')<CR>
nnoremap <silent> <leader>cv :call <SID>MdPreview()<CR>
nnoremap <silent> <C-S-v> :call <SID>MdPreview()<CR>

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
for s:k in ['<F2>', '<F3>', '<F4>', '<F5>', '<F10>', '<F11>', '<F12>', '<C-S-f>', '<C-S-e>', '<C-M-i>', '<C-S-b>', '<C-.>']
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
  execute s:m . 'noremap <C-b> <C-b>'
  execute s:m . 'noremap <C-h> ' . (s:m ==# 'n' ? '<C-w>h' : '<C-h>')
endfor
nnoremap <C-v> <C-v>
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
" termdebug's commands until it is loaded (see "termdebug" above), unless the vimrc loaded it
if exists(':Termdebug') != 2
  command! -nargs=* -complete=file -bang Termdebug call s:TermdebugLoad('Termdebug<bang> ' . <q-args>)
  command! -nargs=+ -complete=file -bang TermdebugCommand call s:TermdebugLoad('TermdebugCommand<bang> ' . <q-args>)
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
" while vim starts, ALE's check of the files opening and the look at their CMake project wait for
" the first screen (12 ms and 5 ms before anything showed)
" (not when this file is read again in a running vim: nothing would turn it back on)
if !v:vim_did_enter
  let s:lint_on_enter = get(g:, 'ale_lint_on_enter', 1)
  let g:ale_lint_on_enter = 0
endif
function! s:Started() abort
  let g:ale_lint_on_enter = s:lint_on_enter
  for b in s:cmake_later
    if bufexists(b)
      call s:CMake(b)
    endif
  endfor
  let s:cmake_later = []
  if s:lint_on_enter && exists('g:loaded_ale')
    for b in uniq(sort(tabpagebuflist()))
      if getbufvar(b, '&buftype') ==# ''
        call ale#Queue(0, 'lint_file', b)
      endif
    endfor
  endif
endfunction
function! s:Info() abort
  echo printf('CPUs %.1f, free memory %d MB: %s mode', s:res.cpus, s:res.mem, s:lite ? 'light' : 'full')
  echo printf('rg threads %d, line blame %s, lint %s', s:jobs,
        \ g:vimzip_blame ? 'on' : 'off', get(g:, 'ale_lint_on_enter', 1) ? 'on open and save' : 'on save')
  let on = map(filter(copy(s:servers), 's:LspState(v:val)[0] ==# "on"'), 'v:val[1] . " (" . s:LspState(v:val)[1] . ")"')
  echo 'language servers: ' . (empty(on) ? 'none on' : join(on, ', ')) . ' (:Lsp to change)'
  echo printf('cache %d MB in %s (old entries are removed daily)', s:CacheSize(), fnamemodify(s:cache, ':~'))
  if &filetype =~# '^\(c\|cpp\|objc\|objcpp\|cuda\)$'
    " where this file's include paths come from
    let own = exists('g:loaded_ale') ? ale#c#FindCompileCommands(bufnr(''))[1] : ''
    let ours = get(get(b:, 'ale_c_build_dir_names', []), 0, '')
    let root = s:CMakeRoot(expand('%:p'))
    let job = get(get(s:cmake, root, {}), 'job', test_null_job())
    if job_status(job) ==# 'run'
      echo 'include paths: CMake is configuring ' . fnamemodify(root, ':~') . '...'
    elseif own !=# '' && (ours ==# '' || stridx(own, ours) != 0)
      echo 'include paths: the project''s ' . fnamemodify(own, ':~')
    elseif ours !=# ''
      let log = ours . '/vimzip-cmake.log'
      let ok = filereadable(log) && match(readfile(log), 'Build files have been written') >= 0
      echo 'include paths: ' . (root ==# '' ? 'guessed (folders with headers, no CMake)'
            \ : ok ? 'from CMake' : 'guessed (CMake failed, see ' . fnamemodify(log, ':~') . ', :CMake retries)')
    else
      echo 'include paths: none found yet (' . (root ==# '' ? 'no CMakeLists.txt' : 'CMake not run') . ')'
    endif
  endif
  if s:lite
    echo 'g:vimzip_lite = 0 in ~/.config/vimzip/vimrc turns light mode off'
  endif
endfunction
command! -bar VimzipInfo call s:Info()
call s:Highlights()
