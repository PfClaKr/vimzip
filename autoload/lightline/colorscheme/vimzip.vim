" VSCode-like tabs (the status bar itself is drawn by vimrc, see themes/)
function! s:c(fg, bg) abort
  return [a:fg, a:bg]
endfunction
let s:white = ['#ffffff', 15]
let s:grey = ['#969696', 246]
let s:bar = s:c(['#d0d0d0', 252], ['#444444', 238])
let s:dim = s:c(['#9d9d9d', 247], ['#252526', 235])

let s:p = {'normal': {}, 'insert': {}, 'visual': {}, 'replace': {}, 'inactive': {}, 'tabline': {}}
let s:p.normal.left = [s:c(['#1c1c1c', 235], ['#bcbcbc', 250]), s:bar, s:bar]
let s:p.normal.middle = [s:bar]
let s:p.normal.right = [s:bar, s:bar, s:bar, s:bar, s:bar]
let s:p.normal.error = [s:c(s:white, ['#c72e0f', 160])]
let s:p.normal.warning = [s:c(['#000000', 16], ['#cca700', 178])]
let s:p.insert.left = [s:c(['#1c1c1c', 235], ['#87afd7', 110]), s:bar, s:bar]
let s:p.visual.left = [s:c(['#1c1c1c', 235], ['#d7af5f', 179]), s:bar, s:bar]
let s:p.replace.left = [s:c(['#1c1c1c', 235], ['#d75f5f', 167]), s:bar, s:bar]
let s:p.inactive.left = [s:dim, s:dim]
let s:p.inactive.middle = [s:dim]
let s:p.inactive.right = [s:dim, s:dim]
let s:p.tabline.left = [s:c(s:grey, ['#2d2d2d', 236])]
let s:p.tabline.tabsel = [s:c(s:white, ['#1e1e1e', 234])]
let s:p.tabline.middle = [s:c(s:grey, ['#252526', 235])]
let s:p.tabline.right = [s:c(s:grey, ['#2d2d2d', 236])]

let g:lightline#colorscheme#vimzip#palette = lightline#colorscheme#flatten(s:p)
