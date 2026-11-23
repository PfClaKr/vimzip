" Space ? : every key and : command, on three pages (keys vimzip adds, vim's own keys, :commands),
" each grouped by topic in two columns on a wide screen. Tab or 1 2 3 change the page, / searches
" all of them as you type, j/k, Ctrl+d/u and the mouse wheel scroll, q or Esc closes.

" [topic, [[keys, what it does], ...]]: keys two spaces apart are alternatives; '>' starts a
" subheading, no keys a note on the entry above
let s:vimzip = [
      \ ['Find', [
      \   ['Ctrl+p  Space ff', 'file by name'],
      \   ['Ctrl+Shift+f  Space fs', 'text in the project'],
      \   ['', 'with a selection: that text'],
      \   ['Space fw', 'word under the cursor'],
      \   ['Space fb  Space fr', 'open files / recent files'],
      \   ['Space ft', 'function or struct by name'],
      \   ['Space fp', 'open another project'],
      \   ['', 'Ctrl+a add (from a folder tree)'],
      \   ['', 'Ctrl+x remove'],
      \   ['', 'Ctrl+e edit the list'],
      \   ['>', 'in the search window'],
      \   ['Enter', 'open'],
      \   ['Ctrl+v  Ctrl+x', 'open beside / below'],
      \   ['Ctrl+j  Ctrl+k', 'next / previous result'],
      \   ['Tab', 'mark a result (several)'],
      \   ['Ctrl+d  Ctrl+u', 'preview half a page down / up'],
      \   ['Ctrl+f  Ctrl+b', 'preview a page down / up'],
      \   ['Shift+Down  Shift+Up', 'preview a line'],
      \   ['Ctrl+/', 'hide / show the preview'],
      \   ['Alt+a  Enter', 'all results to a list'],
      \   ['', 'then :cdo s/a/b/g replaces all'],
      \   ['Esc', 'cancel']]],
      \ ['Tabs and saving', [
      \   ['Tab  Shift+Tab', 'next / previous tab'],
      \   ['click a tab', 'go to it'],
      \   ['Space q', 'close the tab'],
      \   ['Ctrl+s', 'save (autosave is on too)']]],
      \ ['Panels', [
      \   ['Space e  F2', 'file tree (open, focus, close)'],
      \   ['Ctrl+Shift+e', 'file tree (VSCode key)'],
      \   ['Space o  F3', 'outline (functions)'],
      \   ['Space tt  F4', 'terminal at the bottom'],
      \   ['Space a  Ctrl+Alt+i', 'AI agent on the right'],
      \   ['Ctrl+w =', 'panels back to default sizes'],
      \   ['drag an edge', 'resize (the size is kept)']]],
      \ ['In the file tree', [
      \   ['Enter  click', 'open file, open / close folder'],
      \   ['s  i', 'open beside / below'],
      \   ['go', 'open but stay in the tree'],
      \   ['O  X', 'open / close all folders below'],
      \   ['x', 'close the folder you are in'],
      \   ['p  P', 'to the parent folder / the root'],
      \   ['m', 'add, rename, move, copy, delete'],
      \   ['I  R', 'hidden files / refresh'],
      \   ['C  u', 'folder as root / up one'],
      \   ['cd  CD', 'cd into the folder / root to cwd'],
      \   ['A', 'full width / back'],
      \   ['?', "the tree's own help"]]],
      \ ['Terminal', [
      \   ['Space ts  Space tv', 'new terminal below / beside'],
      \   ['Ctrl+w s  Ctrl+w v', '(in a terminal) one more'],
      \   ['Ctrl+v', '(in a terminal) paste'],
      \   ['Ctrl+w N  y  i', 'copy: select, y, back to typing']]],
      \ ['Code', [
      \   ['F12', 'go to definition (as gd)'],
      \   ['Space ce', 'error on this line in full'],
      \   ['Space cf', 'reindent the file'],
      \   ['Space cl', 'language servers on / off'],
      \   ['click the right edge', 'jump to that change'],
      \   ['o', 'picture or PDF: system viewer']]],
      \ ['Git', [
      \   ['Space gs', 'status window'],
      \   ['Space gc', 'commit of this line'],
      \   ['Space gb', 'line blame on / off'],
      \   ['Space gB', 'blame of the whole file'],
      \   ['Space gh', 'history of this file'],
      \   ['', 'with a selection: of those lines'],
      \   ['Space gl', 'graph of all commits'],
      \   ['Space gt', 'timeline under the tree'],
      \   ['Space gd', 'compare with the last commit'],
      \   ['Space gp', 'preview this change'],
      \   ['Space ga  Space gu', 'stage / undo this change']]],
      \ ['In the git status window (Space gs)', [
      \   ['s  u  -', 'stage / unstage / toggle'],
      \   ['=', 'show the diff inline'],
      \   ['dv', 'diff side by side'],
      \   ['X', 'discard the change'],
      \   ['cc  ca', 'commit / amend the last commit'],
      \   ['Enter', 'open the file'],
      \   ['q', 'close']]],
      \ ['In history, blame, timeline', [
      \   ['Enter  o', 'show that commit'],
      \   ['q', 'close (timeline: back to file)']]],
      \ ['Debug (gdb)', [
      \   ['Space dd  F5', 'start / continue'],
      \   ['Space db  F9', 'breakpoint (also before start)'],
      \   ['Space dn  F10', 'next line'],
      \   ['Space di  F11', 'step into'],
      \   ['Space do  Shift+F11', 'step out'],
      \   ['K', '(debugging) value under cursor'],
      \   ['click Step  Next ...', 'the buttons over the source']]],
      \ ['More', [
      \   ['Space ?', 'this help']]],
      \ ]

let s:vim = [
      \ ['Move', [
      \   ['h  j  k  l', 'left, down, up, right'],
      \   ['w  b  e', 'next word / back / word end'],
      \   ['0  ^  $', 'line start / first char / end'],
      \   ['gg  G  12G', 'top / bottom / line 12'],
      \   ['{  }', 'previous / next blank line'],
      \   ['H  M  L', 'screen top / middle / bottom'],
      \   ['f x  t x  ;', 'to / before x in line, again'],
      \   ['%', 'matching bracket'],
      \   ['Ctrl+o  Ctrl+i', 'back / forward in jumps'],
      \   ['`.  gi', 'last change / type there again'],
      \   ['m a  `a', 'set mark a / go back to it']]],
      \ ['Scroll', [
      \   ['Ctrl+d  Ctrl+u', 'half a page down / up'],
      \   ['Ctrl+f  Ctrl+b', 'a page down / up'],
      \   ['Ctrl+e  Ctrl+y', 'one line down / up'],
      \   ['zz  zt  zb', 'this line to middle / top / end']]],
      \ ['Edit', [
      \   ['i  a', 'type before / after the cursor'],
      \   ['I  A', 'type at line start / end'],
      \   ['o  O', 'type on a new line below / above'],
      \   ['Esc', 'stop typing'],
      \   ['x  dd  D', 'delete char / line / to the end'],
      \   ['yy  p  P', 'copy line / paste after / before'],
      \   ['cw  cc  C', 'retype word / line / to the end'],
      \   ['ciw  ci"  ci(', 'retype word / in quotes / in ()'],
      \   ['diw  da(  yi{', 'delete, copy... the same way'],
      \   ['r x  ~', 'replace with x / switch case'],
      \   ['J', 'join with the next line'],
      \   ['Ctrl+a  Ctrl+x', 'number + 1 / - 1'],
      \   ['u  Ctrl+r', 'undo / redo (kept after restart)'],
      \   ['.', 'repeat the last change'],
      \   ['>>  <<', 'indent / unindent'],
      \   ['gcc  gc', 'comment line / selection'],
      \   ['=', 'reindent the selection']]],
      \ ['While typing', [
      \   ['Ctrl+n  Ctrl+p', 'complete the word'],
      \   ['Ctrl+w  Ctrl+u', 'delete word / to line start'],
      \   ['Ctrl+r "', 'paste what you copied'],
      \   ['Ctrl+o', 'one normal-mode command']]],
      \ ['Select', [
      \   ['v  V  Ctrl+v', 'characters / lines / block'],
      \   ['gv', 'the last selection again'],
      \   ['o', 'go to the other end'],
      \   ['>', 'then, on the selection'],
      \   ['y  Ctrl+c', 'copy (local clipboard too)'],
      \   ['d  c', 'delete / retype'],
      \   ['>  <  =', 'indent / unindent / reindent'],
      \   ['I  A', '(block) type on every line']]],
      \ ['Find and replace', [
      \   ['/text  n  N', 'find in this file / next / prev'],
      \   ['?text', 'find backwards'],
      \   ['*  #', 'word under cursor / backwards']]],
      \ ['Code', [
      \   ['gd', 'definition (system headers too)'],
      \   ['gr  K', 'references / documentation'],
      \   [']e  [e', 'next / previous error'],
      \   [']c  [c', 'next / previous change']]],
      \ ['Registers and macros', [
      \   ['"ay  "ap', 'copy to / paste from register a'],
      \   ['qa ... q', 'record keys into a'],
      \   ['@a  @@', 'play a / play again']]],
      \ ['Windows (after Ctrl+w)', [
      \   ['s  v', 'split below / beside'],
      \   ['q  o', 'close / close all others'],
      \   ['h j k l  w', 'go that way / next window'],
      \   ['+  -  <  >', 'resize'],
      \   ['_  |', 'maximize height / width'],
      \   ['x  r', 'swap / rotate'],
      \   ['H J K L', 'move the window to that side'],
      \   ['', 'Ctrl+h j k l move windows too']]],
      \ ['In a terminal', [
      \   ['Ctrl+w N', 'scroll, copy (i types again)'],
      \   ['Ctrl+w :', 'a vim command'],
      \   ['Ctrl+w h j k l', 'another window']]],
      \ ['Files and quitting', [
      \   ['ZZ  ZQ', 'close the tab / without saving'],
      \   ['', 'the last tab: quit vim']]],
      \ ]

" commands typed after :
let s:plugin_cmds = [
      \ ['vimzip', [
      \   [':VimzipInfo', 'CPUs, memory, light or full mode'],
      \   [':Lsp  :Lsp rust off', 'language servers: list, switch'],
      \   [':CMake', 'read include paths from CMake again'],
      \   [':Find text', 'search the project'],
      \   [':Project path', 'open another project'],
      \   [':Theme name', 'status bar colors (:Theme lists)']]],
      \ ['Search (fzf.vim)', [
      \   [':Files  :GFiles', 'files / files in git'],
      \   [':Buffers  :History', 'open / recent files'],
      \   [':Rg text', 'search with ripgrep'],
      \   [':Lines  :BLines', 'lines in open files / this file'],
      \   [':Tags  :BTags', 'symbols in project / this file'],
      \   [':Commits  :BCommits', 'commits / of this file'],
      \   [':Marks  :Jumps', 'marks / jump list'],
      \   [':Maps  :Commands', 'search every key / command'],
      \   [':Helptags', 'search the vim help']]],
      \ ['Git (fugitive, GV)', [
      \   [':Git', 'status window'],
      \   [':Git commit  :Git push', 'commit / push'],
      \   [':Git pull  :Git log', 'pull / log'],
      \   [':Git any-command', 'any git command'],
      \   [':Gwrite  :Gread', 'stage the file / discard changes'],
      \   [':Gdiffsplit [rev]', 'compare (:Gvdiffsplit beside)'],
      \   [':GMove  :GRename', 'move / rename the file in git'],
      \   [':GDelete', 'delete the file in git'],
      \   [':Gedit rev:file', 'a file as it was in a commit'],
      \   [':Ggrep text', 'git grep, results in a list'],
      \   [':GV  :GV!', 'commit graph / of this file']]],
      \ ['Changes (gitgutter)', [
      \   [':GitGutterQuickFix', 'all changes to a list'],
      \   [':GitGutterFold', 'fold the unchanged lines'],
      \   [':GitGutterToggle', 'change signs on / off']]],
      \ ['Errors and code (ALE)', [
      \   [':ALEInfo', 'linters and their output'],
      \   [':ALELint  :ALEToggle', 'check now / checking on, off'],
      \   [':ALEFindReferences', 'references (language server)'],
      \   [':ALERename', 'rename a symbol (lang. server)'],
      \   [':ALECodeAction', 'quick fixes (language server)']]],
      \ ['Tree, outline, tags', [
      \   [':NERDTreeFind', 'show this file in the tree'],
      \   [':NERDTree path', 'tree at another folder'],
      \   [':NERDTreeCWD', 'tree at the current folder'],
      \   [':TagbarToggle', 'outline'],
      \   [':GutentagsUpdate', 'rebuild the tags now']]],
      \ ['Debugger (termdebug)', [
      \   [':TermdebugCommand prog', 'debug prog (with its args)'],
      \   [':Break  :Clear', 'breakpoint here / remove it'],
      \   [':Run  :Continue  :Stop', 'run / continue / interrupt'],
      \   [':Step  :Over  :Finish', 'into / next line / out'],
      \   [':Evaluate expr', 'value of an expression'],
      \   [':Var  :Asm', 'variables / assembly window'],
      \   [':Gdb  :Program', 'gdb / program window'],
      \   [':Source', 'back to the source window']]],
      \ ]

let s:vim_cmds = [
      \ ['Files', [
      \   [':w  :wa', 'save / save all'],
      \   [':e file', 'open a file'],
      \   [':e!', 'reload, dropping changes'],
      \   [':enew', 'a new empty file'],
      \   [':sp file  :vs file', 'open below / beside'],
      \   [':bd', 'close the buffer'],
      \   [':q  :q!', 'close tab / without saving'],
      \   [':qa', 'quit vim'],
      \   [':Man printf', 'a manual page']]],
      \ ['Edit', [
      \   [':%s/a/b/g', 'replace a with b in the file'],
      \   [':%s/a/b/gc', 'the same, asking each time'],
      \   [':g/text/d', 'delete the lines with text'],
      \   [':v/text/d', 'delete the lines without it'],
      \   [':sort  :sort u', 'sort lines / and remove repeats'],
      \   [':earlier 10m', 'the file 10 minutes ago'],
      \   [':later 10m', 'and forward again'],
      \   [':noh', 'clear the search highlight']]],
      \ ['Lists (search results, errors)', [
      \   [':copen  :cclose', 'show / hide the list'],
      \   [':cnext  :cprev', 'next / previous entry'],
      \   [':cdo s/a/b/g', 'replace in every entry'],
      \   [':vimgrep /a/ **/*.c', 'search files into the list']]],
      \ ['Shell', [
      \   [':!make', 'run a command'],
      \   [':r !date', 'insert its output'],
      \   [':terminal', 'a terminal in a split']]],
      \ ['Settings', [
      \   [':set wrap!', 'wrap long lines on / off'],
      \   [':set number!', 'line numbers on / off'],
      \   [':set list!', 'show tabs and spaces'],
      \   [':set paste!', 'paste without auto-indent']]],
      \ ['Information', [
      \   [':reg  :marks', 'registers / marks'],
      \   [':jumps  :changes', 'jump list / change list'],
      \   [':h topic', 'vim help'],
      \   [':messages', 'messages shown earlier']]],
      \ ]

function! s:Highlights() abort
  highlight default link VimzipHelpKey VimzipBar
  highlight default link VimzipHelpTopic Title
  highlight default link VimzipHelpRule NonText
  highlight default link VimzipHelpSub Identifier
  highlight default link VimzipHelpNote Comment
  highlight default link VimzipHelpMatch Search
  for name in ['Key', 'Topic', 'Rule', 'Sub', 'Note', 'Match']
    if empty(prop_type_get('vimzip_help_' . name))
      call prop_type_add('vimzip_help_' . name, {'highlight': 'VimzipHelp' . name, 'priority': name ==# 'Match' ? 20 : 10})
    endif
  endfor
endfunction

let s:pages = [['Keys vimzip adds', 's:vimzip'], ["Vim's own keys", 's:vim'], [':commands', 's:cmds']]
let s:cmds = []

" the keys of an entry as separate chips ('Ctrl+p  Space ff': two alternatives); [text, props]
function! s:Chips(keys) abort
  if a:keys =~# '^\(click\|drag\) '
    return [a:keys, [[0, strlen(a:keys), 'Sub']]]  " a mouse action, not keys
  endif
  let [text, props] = ['', []]
  for k in split(a:keys, '\s\{2,}')
    if text !=# ''
      let text .= ' '
    endif
    call add(props, [strlen(text), strlen(k), 'Key'])
    let text .= k
  endfor
  return [text, props]
endfunction

" text broken at spaces into lines of at most w cells (a longer word is cut)
function! s:Wrap(text, w) abort
  let [lines, line] = [[], '']
  for word in split(a:text, ' ')
    while strwidth(word) > a:w
      if line !=# ''
        call add(lines, line)
        let line = ''
      endif
      let n = a:w
      while strwidth(strcharpart(word, 0, n)) > a:w
        let n -= 1
      endwhile
      call add(lines, strcharpart(word, 0, n))
      let word = strcharpart(word, n)
    endwhile
    if line ==# ''
      let line = word
    elseif strwidth(line . ' ' . word) <= a:w
      let line .= ' ' . word
    else
      call add(lines, line)
      let line = word
    endif
  endfor
  return line ==# '' && !empty(lines) ? lines : lines + [line]
endfunction

" one topic as rows [text, [[byte col (0-based), byte length, highlight], ...]] in a column of
" width w, keys in the first keyw cells. Every row fits, with a cell to spare (a row as wide as the
" popup makes vim widen it past the screen edge): a description too long for its place goes on
" under itself, and on a narrow screen under the keys (the popup's own wrapping would cut words and
" make the last rows unreachable by scrolling)
function! s:Block(topic, rows, w, keyw) abort
  let names = s:Wrap(a:topic, a:w - 3)
  let out = map(names[: -2], '[v:val, [[0, strlen(v:val), "Topic"]]]')
  let rule = repeat('─', max([0, a:w - strwidth(names[-1]) - 2]))
  call add(out, [names[-1] . ' ' . rule, [[0, strlen(names[-1]), 'Topic'], [strlen(names[-1]) + 1, strlen(rule), 'Rule']]])
  let stacked = a:w - a:keyw - 4 < 16
  let indent = stacked ? 4 : a:keyw + 4
  let descw = max([8, a:w - indent - 1])
  for [k, what] in a:rows
    if k ==# '>'
      call add(out, ['  ' . what . ':', [[2, strlen(what) + 1, 'Sub']]])
    elseif k ==# ''
      let pad = repeat(' ', indent)
      for [i, l] in items(s:Wrap(what, descw - 2))
        let l = (i ? '  ' : '↳ ') . l
        call add(out, [pad . l, [[strlen(pad), strlen(l), 'Note']]])
      endfor
    else
      let [chips, props] = s:Chips(k)
      let props = map(props, '[v:val[0] + 2, v:val[1], v:val[2]]')
      let lines = s:Wrap(what, descw)
      if stacked
        call add(out, ['  ' . chips, props])
      else
        let pad = repeat(' ', a:keyw - strwidth(chips) + 2)
        call add(out, ['  ' . chips . pad . remove(lines, 0), props])
      endif
      call extend(out, map(lines, '[repeat(" ", indent) . v:val, []]'))
    endif
  endfor
  return out + [['', []]]
endfunction

" topics laid out in two columns when they fit (each topic stays whole, the columns about even),
" else one
function! s:Layout(topics, width) abort
  let keyw = 0
  let descw = 0
  for [_, rows] in a:topics
    for [k, what] in rows
      if k ==# ''
        let descw = max([descw, strwidth('↳ ' . what)])
      elseif k !=# '>'
        let keyw = max([keyw, strwidth(s:Chips(k)[0])])
        let descw = max([descw, strwidth(what)])
      endif
    endfor
  endfor
  let colw = max([keyw + 5 + descw, 24])  " (one cell to spare, see s:Block)
  let two = 2 * colw + 4 <= a:width
  if !two
    let colw = min([colw, max([20, a:width])])
  endif
  let blocks = map(copy(a:topics), 's:Block(v:val[0], v:val[1], colw, keyw)')
  if !two || len(blocks) < 2
    return [flatten(blocks, 1), colw]
  endif
  " the split that leaves the taller column shortest
  let total = eval(join(map(copy(blocks), 'len(v:val)'), '+'))
  let [best, at, left] = [total, 1, 0]
  for i in range(1, len(blocks) - 1)
    let left += len(blocks[i - 1])
    if max([left, total - left]) < best
      let [best, at] = [max([left, total - left]), i]
    endif
  endfor
  let [l, r] = [flatten(blocks[: at - 1], 1), flatten(blocks[at :], 1)]
  let rows = []
  for i in range(max([len(l), len(r)]))
    let [lt, lp] = get(l, i, ['', []])
    let [rt, rp] = get(r, i, ['', []])
    let lt .= repeat(' ', colw + 4 - strwidth(lt))
    call add(rows, [lt . rt, lp + map(copy(rp), '[v:val[0] + strlen(lt), v:val[1], v:val[2]]')])
  endfor
  return [rows, 2 * colw + 4]
endfunction

" the rows of every page whose keys or description contain the query, under their topics
function! s:Matching(query) abort
  let found = []
  for [title, var] in s:pages
    for [topic, rows] in eval(var)
      " a topic whose name matches comes whole, else just its matching entries
      let hits = stridx(tolower(topic), tolower(a:query)) >= 0 ? rows
            \ : filter(copy(rows), 'v:val[0] !~# "^>\\=$" && stridx(tolower(v:val[0] . " " . v:val[1]), tolower(a:query)) >= 0')
      if !empty(hits)
        call add(found, [topic . '  (' . title . ')', hits])
      endif
    endfor
  endfor
  return found
endfunction

function! s:Render() abort
  let width = &columns - 6
  if s:query !=# ''
    let [rows, w] = s:Layout(s:Matching(s:query), width)
    if empty(rows)
      let rows = [['No key or command contains "' . s:query . '"', [[0, 0, 'Note']]]]
    endif
  else
    let [rows, w] = s:Layout(eval(s:pages[s:page][1]), width)
  endif
  " the query highlighted where it appears
  if s:query !=# ''
    for r in rows
      let i = stridx(tolower(r[0]), tolower(s:query))
      while i >= 0
        call add(r[1], [i, strlen(s:query), 'Match'])
        let i = stridx(tolower(r[0]), tolower(s:query), i + 1)
      endwhile
    endfor
  endif
  let text = map(rows, {_, r -> {'text': r[0], 'props': map(filter(copy(r[1]), 'v:val[1] > 0'),
        \ {_, p -> {'col': p[0] + 1, 'length': p[1], 'type': 'vimzip_help_' . p[2]}})}})
  " one size for every page and search, the largest page's: the box does not jump about
  if !exists('s:size')
    let s:size = [0, 0]
    for [_, var] in s:pages
      let [r, pw] = s:Layout(eval(var), width)
      let s:size = [max([s:size[0], min([pw, width])]), max([s:size[1], min([len(r), &lines - 4])])]
    endfor
  endif
  call popup_settext(s:id, text)
  call popup_setoptions(s:id, {'title': s:Title(), 'minheight': s:size[1], 'maxheight': s:size[1],
        \ 'minwidth': s:size[0], 'maxwidth': s:size[0], 'firstline': 1})
  let s:first = 1
  let s:last = max([1, len(text) - s:size[1] + 1])
endfunction

" the pages as tabs, the current one in brackets; or the search being typed
function! s:Title() abort
  if s:typing || s:query !=# ''
    return printf(' Search: %s%s   %s ', s:query, s:typing ? '_' : '',
          \ s:typing ? 'Enter: keep   Esc: clear' : '/ search again   Esc: all keys   q close')
  endif
  let tabs = map(copy(s:pages), {i, p -> i == s:page ? '[' . (i + 1) . ' ' . p[0] . ']' : ' ' . (i + 1) . ' ' . p[0] . ' '})
  return ' ' . join(tabs, ' ') . '     Tab next page   / search   j k scroll   q close '
endfunction

function! vimzip#keys#show() abort
  call s:Highlights()
  let s:cmds = map(copy(s:plugin_cmds), '[v:val[0], v:val[1]]') + s:vim_cmds
  let [s:page, s:query, s:typing] = [get(s:, 'page', 0), '', 0]
  unlet! s:size
  let s:id = popup_create('', {'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'padding': [0, 1, 0, 1], 'scrollbar': 1, 'filter': function('s:Filter'), 'mapping': 0,
        \ 'zindex': 300, 'highlight': 'Normal'})
  call s:Render()
endfunction

function! s:Filter(id, key) abort
  if s:typing
    if a:key ==# "\<CR>"
      let s:typing = 0
    elseif a:key ==# "\<Esc>"
      let [s:typing, s:query] = [0, '']
    elseif a:key ==# "\<BS>" || a:key ==# "\<C-h>"
      let s:query = s:query[: -2]
    elseif a:key ==# "\<C-u>"
      let s:query = ''
    elseif a:key =~# '^\p$' || (strchars(a:key) == 1 && char2nr(a:key) > 127)
      let s:query .= a:key
    else
      return a:key[0] ==# "\x80" ? 0 : 1
    endif
    call s:Render()
    return 1
  endif
  let page = popup_getpos(a:id).core_height
  let steps = {'j': 1, "\<Down>": 1, "\<C-e>": 1, "\<ScrollWheelDown>": 3,
        \ 'k': -1, "\<Up>": -1, "\<C-y>": -1, "\<ScrollWheelUp>": -3,
        \ "\<C-d>": page / 2, "\<C-u>": -page / 2, "\<C-f>": page, "\<PageDown>": page, ' ': page,
        \ "\<C-b>": -page, "\<PageUp>": -page, 'g': -9999, 'G': 9999}
  if has_key(steps, a:key)
    let s:first = max([1, min([s:last, s:first + steps[a:key]])])
    call popup_setoptions(a:id, {'firstline': s:first})
    return 1
  endif
  let pages = {"\<Tab>": 1, "\<S-Tab>": -1, 'l': 1, 'h': -1, "\<Right>": 1, "\<Left>": -1}
  if has_key(pages, a:key) || a:key =~# '^[1-3]$'
    let s:page = a:key =~# '^[1-3]$' ? a:key - 1 : (s:page + pages[a:key] + 3) % 3
    let s:query = ''
    call s:Render()
    return 1
  endif
  if a:key ==# '/'
    let [s:typing, s:query] = [1, '']
    call s:Render()
    return 1
  endif
  if a:key ==# "\<Esc>" && s:query !=# ''
    let s:query = ''
    call s:Render()
    return 1
  endif
  if index(['q', 'x', "\<Esc>", '?', "\<CR>", "\<LeftMouse>"], a:key) >= 0
    call popup_close(a:id)
    return 1
  endif
  " vim's own events (cursor hold, mouse moves) pass; any other key closes the page and does its
  " usual job (':' starts a command), instead of being swallowed with the page left on the screen
  if a:key[0] !=# "\x80"
    call popup_close(a:id)
  endif
  return 0
endfunction
