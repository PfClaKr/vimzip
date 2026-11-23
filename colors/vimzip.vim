" vimzip: VSCode's Dark+ colors for code. The screen itself (popups, selection, line numbers)
" starts from habamax; the background stays the terminal's own (see the vimrc's vimzip_bg).
" Functions, variables, members, types and constants get their own colors from the matches the
" vimrc adds per language (s:CodeSyntax), which vim's syntax files do not tell apart.
runtime colors/habamax.vim
let g:colors_name = 'vimzip'

let s:c = {
  \ 'fg': ['#d4d4d4', 188], 'comment': ['#6a9955', 65], 'string': ['#ce9178', 174],
  \ 'number': ['#b5cea8', 151], 'keyword': ['#569cd6', 68], 'control': ['#c586c0', 176],
  \ 'function': ['#dcdcaa', 187], 'variable': ['#9cdcfe', 153], 'type': ['#4ec9b0', 79],
  \ 'constant': ['#4fc1ff', 75], 'escape': ['#d7ba7d', 180], 'error': ['#f44747', 203],
  \ 'gray': ['#858585', 102], 'dim': ['#3b3b3b', 237], 'line': ['#2a2d2e', 235],
  \ 'select': ['#264f78', 24], 'menu': ['#252526', 235], 'menusel': ['#04395e', 24],
  \ 'search': ['#613214', 94], 'cursearch': ['#515c6a', 60], 'match': ['#3a3d41', 238]}

function! s:Hi(group, fg, ...) abort
  let bg = a:0 ? a:1 : ''
  let attr = a:0 > 1 ? a:2 : 'NONE'
  execute 'highlight' a:group
        \ 'guifg=' . (a:fg ==# '' ? 'NONE' : s:c[a:fg][0]) 'ctermfg=' . (a:fg ==# '' ? 'NONE' : s:c[a:fg][1])
        \ 'guibg=' . (bg ==# '' ? 'NONE' : s:c[bg][0]) 'ctermbg=' . (bg ==# '' ? 'NONE' : s:c[bg][1])
        \ 'gui=' . attr 'cterm=' . attr
endfunction

call s:Hi('Normal', 'fg')
call s:Hi('Comment', 'comment')
for s:g in ['String', 'Character']
  call s:Hi(s:g, 'string')
endfor
for s:g in ['Number', 'Float']
  call s:Hi(s:g, 'number')
endfor
for s:g in ['Boolean', 'Statement', 'Keyword', 'Type', 'StorageClass', 'Structure', 'Typedef']
  call s:Hi(s:g, 'keyword')
endfor
call s:Hi('Operator', 'fg')
for s:g in ['Conditional', 'Repeat', 'Label', 'Exception', 'PreProc', 'Include', 'Define', 'Macro', 'PreCondit']
  call s:Hi(s:g, 'control')
endfor
call s:Hi('Function', 'function')
call s:Hi('Identifier', 'variable')
call s:Hi('Constant', 'constant')
for s:g in ['Special', 'SpecialChar', 'Tag', 'SpecialComment', 'Debug']
  call s:Hi(s:g, 'escape')
endfor
call s:Hi('Delimiter', 'fg')
call s:Hi('Title', 'keyword', '', 'bold')
call s:Hi('Todo', 'keyword', '', 'bold')
call s:Hi('Error', 'error')

" the matches the vimrc adds for code
call s:Hi('vimzipFunction', 'function')
call s:Hi('vimzipVariable', 'variable')
call s:Hi('vimzipMember', 'variable')
call s:Hi('vimzipType', 'type')
call s:Hi('vimzipConstant', 'constant')

" languages whose syntax names things itself
highlight! link cStatement Conditional
highlight! link cppStatement Conditional
highlight! link pythonClass vimzipType
highlight! link pythonClassVar Keyword
highlight! link luaFunction Keyword
highlight! link luaFunc vimzipFunction
highlight! link rustModPath vimzipType
for s:g in ['typescriptVariableDeclaration', 'typescriptIdentifierName', 'typescriptCall',
      \ 'typescriptDestructureVariable', 'typescriptArrowFuncArg', 'typescriptParamImpl']
  execute 'highlight! link' s:g 'vimzipVariable'
endfor
for s:g in ['typescriptProp', 'typescriptObjectLabel', 'typescriptMember']
  execute 'highlight! link' s:g 'vimzipMember'
endfor
for s:g in ['typescriptClassName', 'typescriptClassHeritage', 'typescriptTypeReference',
      \ 'typescriptGlobal', 'typescriptInterfaceName', 'typescriptAliasDeclaration', 'typescriptEnum']
  execute 'highlight! link' s:g 'vimzipType'
endfor
highlight! link typescriptFuncName vimzipFunction
highlight! link typescriptFuncCallArg Normal

" the screen, closer to VSCode's
call s:Hi('LineNr', 'gray')
call s:Hi('CursorLineNr', 'fg')
call s:Hi('CursorLine', '', 'line')
call s:Hi('Visual', '', 'select')
call s:Hi('Search', '', 'search')
call s:Hi('CurSearch', '', 'cursearch')
call s:Hi('IncSearch', '', 'cursearch')
call s:Hi('MatchParen', '', 'match', 'bold')
call s:Hi('Pmenu', 'fg', 'menu')
call s:Hi('PmenuSel', 'fg', 'menusel')
call s:Hi('NonText', 'dim')
call s:Hi('EndOfBuffer', 'dim')
call s:Hi('SpecialKey', 'dim')
