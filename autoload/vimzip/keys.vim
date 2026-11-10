" Space ? : every key on one page, in two halves (keys vimzip adds / vim's own keys), each by topic.
" Side by side on a wide screen, one under the other on a narrow one. j/k, Ctrl+d/u, the mouse
" wheel scroll; q or Esc closes.

" [topic, [[keys, what it does], ...]]; an entry with no keys is a small note under the topic
let s:vimzip = [
      \ ['찾기', [
      \   ['Ctrl+p  Space ff', '파일 이름으로 찾기'],
      \   ['Ctrl+Shift+f  Space fs', '프로젝트 전체에서 글자 찾기'],
      \   ['', '선택한 상태면 그 글자로 찾기'],
      \   ['Space fw', '커서 아래 단어로 찾기'],
      \   ['Space fb  Space fr', '열린 파일 / 최근 파일'],
      \   ['Space ft', '함수·구조체 이름으로 찾기'],
      \   ['Space fp', '다른 프로젝트 열기'],
      \   ['', '검색 창 안에서'],
      \   ['Enter', '열기'],
      \   ['Ctrl+v  Ctrl+x', '옆에 / 아래에 열기'],
      \   ['Ctrl+d  Ctrl+u', '미리보기 반 페이지 아래 / 위'],
      \   ['Ctrl+f  Ctrl+b', '미리보기 한 페이지 아래 / 위'],
      \   ['Shift+↓  Shift+↑', '미리보기 한 줄'],
      \   ['Ctrl+/', '미리보기 숨기기 / 보이기'],
      \   ['Alt+a  Enter', '결과 전부를 목록으로'],
      \   ['', '→ :cdo s/a/b/g 로 한꺼번에 바꾸기']]],
      \ ['탭과 저장', [
      \   ['Tab  Shift+Tab', '다음 / 이전 탭'],
      \   ['탭 클릭', '그 탭으로'],
      \   ['Space q', '탭 닫기'],
      \   ['Ctrl+s', '저장 (자동 저장도 켜져 있음)']]],
      \ ['패널', [
      \   ['Space e  F2', '파일 트리 (열기 → 트리로 → 닫기)'],
      \   ['Ctrl+Shift+e', '파일 트리 (VSCode 키)'],
      \   ['Space o  F3', '함수 목록'],
      \   ['Space tt  F4', '아래 터미널 열기 / 숨기기'],
      \   ['Space a  Ctrl+Alt+i', '오른쪽 AI 에이전트 열기 / 숨기기'],
      \   ['Ctrl+w =', '창·패널 크기를 기본으로']]],
      \ ['파일 트리 안에서', [
      \   ['Enter  클릭', '열기'],
      \   ['s  i', '옆에 / 아래에 열기'],
      \   ['m', '파일 추가·이름 바꾸기·삭제'],
      \   ['I  R', '숨김 파일 보기 / 새로고침'],
      \   ['C  u', '이 폴더를 루트로 / 상위 폴더로'],
      \   ['A', '트리를 화면 가득 / 원래대로']]],
      \ ['터미널', [
      \   ['Space ts  Space tv', '아래 / 옆에 새 터미널'],
      \   ['Ctrl+w s  Ctrl+w v', '(터미널 안) 터미널 하나 더'],
      \   ['Ctrl+v', '(터미널 안) 붙여넣기']]],
      \ ['코드', [
      \   ['F12', '정의로 이동 (gd 와 같음)'],
      \   ['Space ce', '이 줄 에러 자세히'],
      \   ['Space cf', '파일 전체 정렬'],
      \   ['오른쪽 끝 클릭', '그 변경 위치로 (스크롤바 자리)']]],
      \ ['Git', [
      \   ['Space gs', '상태 창'],
      \   ['', 's 올리기 · u 내리기 · cc 커밋 · q 닫기'],
      \   ['Space gc', '이 줄의 커밋 자세히'],
      \   ['Space gb', '줄 끝 커밋 표시 켜기 / 끄기'],
      \   ['Space gB', '파일 전체 blame'],
      \   ['Space gh', '이 파일 히스토리'],
      \   ['Space gl', '전체 커밋 그래프'],
      \   ['Space gt', '타임라인 (Enter 비교, q 복귀)'],
      \   ['Space gd', '마지막 커밋과 비교'],
      \   ['Space gp', '이 변경 미리보기'],
      \   ['Space ga  Space gu', '이 변경 올리기 / 되돌리기']]],
      \ ['디버그 (gdb)', [
      \   ['Space dd  F5', '시작 · 계속'],
      \   ['Space db  F9', '중단점 (시작 전에도)'],
      \   ['Space dn  F10', '다음 줄'],
      \   ['Space di  F11', '함수 안으로'],
      \   ['Space do  Shift+F11', '함수 밖으로']]],
      \ ['그 밖에', [
      \   ['Space ?', '이 도움말'],
      \   [':Theme 이름', '상태바 색 (:Theme 만 치면 목록)'],
      \   [':Project 경로', '다른 프로젝트 열기']]],
      \ ]

let s:vim = [
      \ ['이동', [
      \   ['h  j  k  l', '← ↓ ↑ →'],
      \   ['w  b  e', '다음 단어 / 이전 단어 / 단어 끝'],
      \   ['0  ^  $', '줄 맨 앞 / 첫 글자 / 줄 끝'],
      \   ['gg  G  12G', '파일 처음 / 끝 / 12번째 줄'],
      \   ['Ctrl+d  Ctrl+u', '반 페이지 아래 / 위'],
      \   ['Ctrl+f  Ctrl+b', '한 페이지 아래 / 위'],
      \   ['f x  t x', '이 줄에서 x 로 / x 앞으로'],
      \   ['%', '짝 괄호로'],
      \   ['Ctrl+o  Ctrl+i', '이전 / 다음 위치로 돌아가기']]],
      \ ['편집', [
      \   ['i  a', '커서 앞 / 뒤에서 입력 시작'],
      \   ['o  O', '아래 / 위에 새 줄 만들고 입력'],
      \   ['Esc', '입력 끝내기'],
      \   ['x  dd  D', '글자 / 줄 / 줄 끝까지 지우기'],
      \   ['yy  p  P', '줄 복사 / 뒤에 붙여넣기 / 앞에'],
      \   ['ciw  cc', '단어 / 줄 바꿔 쓰기'],
      \   ['u  Ctrl+r', '실행 취소 / 다시 실행'],
      \   ['.', '방금 한 편집 반복'],
      \   ['>>  <<', '들여쓰기 / 내어쓰기'],
      \   ['gcc  gc', '줄 / 선택 영역 주석'],
      \   ['=', '선택 영역 정렬'],
      \   ['Ctrl+n  Ctrl+p', '(입력 중) 자동완성']]],
      \ ['선택', [
      \   ['v  V  Ctrl+v', '글자 / 줄 / 사각형 선택'],
      \   ['', '선택한 다음에'],
      \   ['y  Ctrl+c', '복사 (SSH 너머 클립보드로도)'],
      \   ['d  >  <', '지우기 / 들여쓰기 / 내어쓰기']]],
      \ ['찾기와 바꾸기', [
      \   ['/글자  n  N', '이 파일에서 찾기 / 다음 / 이전'],
      \   ['*', '커서 아래 단어 찾기'],
      \   [':%s/a/b/g', '이 파일에서 a 를 b 로 바꾸기']]],
      \ ['코드', [
      \   ['gd', '정의로 이동 (시스템 헤더 포함)'],
      \   ['gr  K', '참조 찾기 / 설명 보기'],
      \   [']e  [e', '다음 / 이전 에러'],
      \   [']c  [c', '다음 / 이전 변경 위치']]],
      \ ['창 (Ctrl+w 다음에)', [
      \   ['s  v', '아래 / 옆으로 나누기'],
      \   ['q', '창 닫기 (마지막이면 :q 처럼)'],
      \   ['h j k l  w', '그 방향 창으로 / 다음 창'],
      \   ['+  -  <  >', '크기 조절 (경계를 끌어도 됨)'],
      \   ['_  |', '높이 / 너비 최대로'],
      \   ['x  H J K L', '옆 창과 바꾸기 / 창 옮기기'],
      \   ['', 'Ctrl+h j k l 로도 창 이동']]],
      \ ['터미널 안에서', [
      \   ['Ctrl+w N', '스크롤·복사 모드 (i 로 돌아가기)'],
      \   ['Ctrl+w :', 'vim 명령 입력'],
      \   ['Ctrl+w h j k l', '다른 창으로']]],
      \ ['파일과 종료', [
      \   [':w', '저장'],
      \   [':q  ZZ', '탭 닫기 (마지막 탭이면 vim 종료)'],
      \   [':q!  ZQ', '저장하지 않고 닫기'],
      \   [':qa', 'vim 종료'],
      \   [':e 파일', '파일 열기']]],
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
  let [left, lw] = s:Half('vimzip 이 더한 키', s:vimzip)
  let [right, rw] = s:Half('vim 기본 키 (그대로 동작)', s:vim)
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
  let s:help = popup_create(text, {'title': ' 단축키 · j k 스크롤 · q 닫기 ', 'border': [],
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
