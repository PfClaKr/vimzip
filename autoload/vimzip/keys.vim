" Space ? : every key on one page, in two halves (keys vimzip adds / vim's own keys), each by topic.
" Side by side on a wide screen, one under the other on a narrow one. j/k, Ctrl+d/u, the mouse
" wheel scroll; q or Esc closes.

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
      \   ['Ctrl+d  Ctrl+u', 'preview half a page down / up'],
      \   ['Ctrl+f  Ctrl+b', 'preview a page down / up'],
      \   ['Shift+Down  Shift+Up', 'preview a line'],
      \   ['Ctrl+/', 'hide / show the preview'],
      \   ['Alt+a  Enter', 'all results to a list'],
      \   ['', 'then :cdo s/a/b/g replaces in all']]],
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
      \   ['Ctrl+w =', 'panels back to default sizes']]],
      \ ['In the file tree', [
      \   ['Enter  click', 'open'],
      \   ['s  i', 'open beside / below'],
      \   ['m', 'add, rename, delete'],
      \   ['I  R', 'hidden files / refresh'],
      \   ['C  u', 'folder as root / up one'],
      \   ['A', 'full width / back']]],
      \ ['Terminal', [
      \   ['Space ts  Space tv', 'new terminal below / beside'],
      \   ['Ctrl+w s  Ctrl+w v', '(in a terminal) one more'],
      \   ['Ctrl+v', '(in a terminal) paste']]],
      \ ['Code', [
      \   ['F12', 'go to definition (as gd)'],
      \   ['Space ce', 'error on this line in full'],
      \   ['Space cf', 'reindent the file'],
      \   ['click the right edge', 'jump to that change']]],
      \ ['Git', [
      \   ['Space gs', 'status window'],
      \   ['', 's stage, u unstage, cc commit, q close'],
      \   ['Space gc', 'commit of this line'],
      \   ['Space gb', 'line blame on / off'],
      \   ['Space gB', 'blame of the whole file'],
      \   ['Space gh', 'history of this file'],
      \   ['Space gl', 'graph of all commits'],
      \   ['Space gt', 'timeline (Enter compare, q back)'],
      \   ['Space gd', 'compare with the last commit'],
      \   ['Space gp', 'preview this change'],
      \   ['Space ga  Space gu', 'stage / undo this change']]],
      \ ['Debug (gdb)', [
      \   ['Space dd  F5', 'start / continue'],
      \   ['Space db  F9', 'breakpoint (also before start)'],
      \   ['Space dn  F10', 'next line'],
      \   ['Space di  F11', 'step into'],
      \   ['Space do  Shift+F11', 'step out']]],
      \ ['More', [
      \   ['Space ?', 'this help'],
      \   [':Theme name', 'status bar colors (:Theme lists)'],
      \   [':Project path', 'open another project']]],
      \ ]

let s:vim = [
      \ ['Move', [
      \   ['h  j  k  l', 'left, down, up, right'],
      \   ['w  b  e', 'next word / back / word end'],
      \   ['0  ^  $', 'line start / first char / end'],
      \   ['gg  G  12G', 'top / bottom / line 12'],
      \   ['Ctrl+d  Ctrl+u', 'half a page down / up'],
      \   ['Ctrl+f  Ctrl+b', 'a page down / up'],
      \   ['f x  t x', 'to / before x on this line'],
      \   ['%', 'matching bracket'],
      \   ['Ctrl+o  Ctrl+i', 'back / forward in jumps']]],
      \ ['Edit', [
      \   ['i  a', 'type before / after the cursor'],
      \   ['o  O', 'type on a new line below / above'],
      \   ['Esc', 'stop typing'],
      \   ['x  dd  D', 'delete char / line / to the end'],
      \   ['yy  p  P', 'copy line / paste after / before'],
      \   ['ciw  cc', 'retype word / line'],
      \   ['u  Ctrl+r', 'undo / redo (kept after restart)'],
      \   ['.', 'repeat the last change'],
      \   ['>>  <<', 'indent / unindent'],
      \   ['gcc  gc', 'comment line / selection'],
      \   ['=', 'reindent the selection'],
      \   ['Ctrl+n  Ctrl+p', '(typing) complete the word']]],
      \ ['Select', [
      \   ['v  V  Ctrl+v', 'characters / lines / block'],
      \   ['', 'then'],
      \   ['y  Ctrl+c', 'copy (to the local clipboard too)'],
      \   ['d  >  <', 'delete / indent / unindent']]],
      \ ['Find and replace', [
      \   ['/text  n  N', 'find in this file / next / prev'],
      \   ['*', 'word under the cursor'],
      \   [':%s/a/b/g', 'replace a with b in this file']]],
      \ ['Code', [
      \   ['gd', 'go to definition (system headers too)'],
      \   ['gr  K', 'references / documentation'],
      \   [']e  [e', 'next / previous error'],
      \   [']c  [c', 'next / previous change']]],
      \ ['Windows (after Ctrl+w)', [
      \   ['s  v', 'split below / beside'],
      \   ['q', 'close (the last one: like :q)'],
      \   ['h j k l  w', 'go that way / next window'],
      \   ['+  -  <  >', 'resize (or drag the edge)'],
      \   ['_  |', 'maximize height / width'],
      \   ['x  H J K L', 'swap / move the window'],
      \   ['', 'Ctrl+h j k l move between windows too']]],
      \ ['In a terminal', [
      \   ['Ctrl+w N', 'scroll and copy (i to type again)'],
      \   ['Ctrl+w :', 'a vim command'],
      \   ['Ctrl+w h j k l', 'another window']]],
      \ ['Files and quitting', [
      \   [':w', 'save'],
      \   [':q  ZZ', 'close the tab (the last: quit vim)'],
      \   [':q!  ZQ', 'close without saving'],
      \   [':qa', 'quit vim'],
      \   [':e file', 'open a file']]],
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

function! vimzip#keys#show() abort
  call s:Highlights()
  let [left, lw] = s:Half('Added by vimzip', s:vimzip)
  let [right, rw] = s:Half("Vim's own keys (they all work)", s:vim)
  let gap = 4
  let rows = []
  if lw + gap + rw + 4 <= &columns
    " side by side
    for i in range(max([len(left), len(right)]))
      let [lt, lp] = get(left, i, ['', []])
      let [rt, rp] = get(right, i, ['', []])
      let lt .= repeat(' ', lw - strdisplaywidth(lt) + gap)
      let props = copy(lp)
      for [col, len, type] in rp
        call add(props, [col + strlen(lt), len, type])
      endfor
      call add(rows, [lt . rt, props])
    endfor
  else
    let rows = left + right
  endif
  let text = map(rows, {_, r -> {'text': r[0], 'props': map(copy(r[1]),
        \ {_, p -> {'col': p[0], 'length': p[1], 'type': 'vimzip_help_' . p[2]}})}})
  let height = min([len(text), &lines - 4])
  let s:help = popup_create(text, {'title': ' Keys   j k scroll   q close ', 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'], 'padding': [0, 1, 0, 1],
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
