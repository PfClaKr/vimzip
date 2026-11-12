" Space ? : every key and : command on one page. Two parts, keys then commands, each in two
" halves (what vimzip and its plugins add / what vim has anyway), grouped by topic. Side by side on
" a wide screen, one under the other on a narrow one. j/k, Ctrl+d/u and the mouse wheel scroll,
" Tab jumps between keys and commands, q or Esc closes.

" [topic, [[keys, what it does], ...]]; an entry with no keys is a small note under the topic
let s:vimzip = [
      \ ['Find', [
      \   ['Ctrl+p  Space ff', 'file by name'],
      \   ['Ctrl+Shift+f  Space fs', 'text in the project'],
      \   ['', 'with a selection: that text'],
      \   ['Space fw', 'word under the cursor'],
      \   ['Space fb  Space fr', 'open files / recent files'],
      \   ['Space ft', 'function or struct by name'],
      \   ['Space fp', 'open another project'],
      \   ['', 'in the search window'],
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
      \   ['click the right edge', 'jump to that change']]],
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
      \   ['', 'then'],
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
      \   [':ALEFindReferences', 'references (clangd)'],
      \   [':ALERename', 'rename a symbol (clangd)'],
      \   [':ALECodeAction', 'quick fixes (clangd)']]],
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
  highlight default link VimzipHelpKey Function
  highlight default link VimzipHelpTopic Title
  highlight default link VimzipHelpNote Comment
  highlight default link VimzipHelpHalf VimzipBar
  for [name, hl] in [['key', 'VimzipHelpKey'], ['topic', 'VimzipHelpTopic'], ['note', 'VimzipHelpNote'], ['half', 'VimzipHelpHalf']]
    if empty(prop_type_get('vimzip_help_' . name))
      call prop_type_add('vimzip_help_' . name, {'highlight': hl})
    endif
  endfor
endfunction

" one half as rows of [text, [[byte col, byte length, prop], ...]], all padded to the same width
function! s:Half(title, topics) abort
  let keyw = 0
  for [_, rows] in a:topics
    for [k, _] in rows
      let keyw = max([keyw, strdisplaywidth(k)])
    endfor
  endfor
  let out = [[' ' . a:title . ' ', [[1, strlen(a:title) + 2, 'half']]], ['', []]]
  for [topic, rows] in a:topics
    call add(out, [' ' . topic, [[2, strlen(topic), 'topic']]])
    for [k, what] in rows
      if k ==# ''
        call add(out, ['   ' . what, [[4, strlen(what), 'note']]])
      else
        let pad = repeat(' ', keyw - strdisplaywidth(k) + 3)
        call add(out, ['   ' . k . pad . what, [[4, strlen(k), 'key']]])
      endif
    endfor
    call add(out, ['', []])
  endfor
  let width = max(map(copy(out), 'strdisplaywidth(v:val[0])'))
  return [out, width]
endfunction

" two halves side by side when the screen is wide enough, else one under the other
function! s:Pair(left, right, side) abort
  let [left, lw] = a:left
  let [right, rw] = a:right
  if !a:side
    return left + right
  endif
  let rows = []
  for i in range(max([len(left), len(right)]))
    let [lt, lp] = get(left, i, ['', []])
    let [rt, rp] = get(right, i, ['', []])
    let lt .= repeat(' ', lw - strdisplaywidth(lt) + 4)
    let props = copy(lp)
    for [col, len, type] in rp
      call add(props, [col + strlen(lt), len, type])
    endfor
    call add(rows, [lt . rt, props])
  endfor
  return rows
endfunction

function! vimzip#keys#show() abort
  call s:Highlights()
  let halves = [s:Half('Keys added by vimzip', s:vimzip), s:Half("Vim's own keys (they all work)", s:vim),
        \ s:Half(':commands from the plugins', s:plugin_cmds), s:Half(':commands of vim', s:vim_cmds)]
  let side = max([halves[0][1], halves[2][1]]) + 4 + max([halves[1][1], halves[3][1]]) + 4 <= &columns
  " the same column width in both parts, so the right halves line up
  if side
    let [halves[0][1], halves[2][1]] = repeat([max([halves[0][1], halves[2][1]])], 2)
  endif
  let keys = s:Pair(halves[0], halves[1], side)
  let s:cmds_at = len(keys) + 1
  let rows = keys + s:Pair(halves[2], halves[3], side)
  let text = map(rows, {_, r -> {'text': r[0], 'props': map(copy(r[1]),
        \ {_, p -> {'col': p[0], 'length': p[1], 'type': 'vimzip_help_' . p[2]}})}})
  let height = min([len(text), &lines - 4])
  call popup_create(text, {'title': ' Keys and commands   j k scroll   Tab keys / commands   q close ',
        \ 'border': [], 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1],
        \ 'minheight': height, 'maxheight': height, 'scrollbar': 1, 'filter': function('s:Filter'),
        \ 'mapping': 0, 'zindex': 300, 'highlight': 'Normal'})
  let s:first = 1
  let s:last = max([1, len(text) - height + 1])
endfunction

function! s:Filter(id, key) abort
  let page = popup_getpos(a:id).core_height
  let steps = {'j': 1, "\<Down>": 1, "\<C-e>": 1, "\<ScrollWheelDown>": 3,
        \ 'k': -1, "\<Up>": -1, "\<C-y>": -1, "\<ScrollWheelUp>": -3,
        \ "\<C-d>": page / 2, "\<C-u>": -page / 2, "\<C-f>": page, "\<PageDown>": page, ' ': page,
        \ "\<C-b>": -page, "\<PageUp>": -page, 'g': -9999, 'G': 9999}
  if a:key ==# "\<Tab>"
    let s:first = s:first < s:cmds_at ? min([s:cmds_at, s:last]) : 1
    call popup_setoptions(a:id, {'firstline': s:first})
    return 1
  endif
  if has_key(steps, a:key)
    let s:first = max([1, min([s:last, s:first + steps[a:key]])])
    call popup_setoptions(a:id, {'firstline': s:first})
    return 1
  endif
  if index(['q', "\<Esc>", '?', "\<CR>", "\<LeftMouse>"], a:key) >= 0
    call popup_close(a:id)
    return 1
  endif
  " vim's own events (cursor hold, mouse moves) pass; any other key is swallowed
  return a:key[0] !=# "\x80"
endfunction
