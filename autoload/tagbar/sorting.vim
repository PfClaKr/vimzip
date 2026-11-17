" vimzip: tagbar's sort, with keys and vim's built-in sort in place of a vimscript comparator
" (called ~500000 times for a file with 5000 symbols: half the outline's time)
function! tagbar#sorting#sort(tags, compareby, compare_typeinfo) abort
  if len(a:tags) > 1
    let [kinds, ci, keys] = [a:compare_typeinfo.kinddict, g:tagbar_case_insensitive, []]
    for i in range(len(a:tags))
      let t = a:tags[i]
      if a:compareby ==# 'kind'
        let name = t.name[0] ==# '~' ? t.name[1:] : t.name  " destructors next to constructors
        let key = printf('%05d', get(kinds, t.fields.kind, -1) + 1) . (ci ? tolower(name) : name)
      else
        let key = printf('%010d', t.fields.line)
      endif
      call add(keys, key . "\x01" . i)
    endfor
    let sorted = map(sort(keys), {_, k -> a:tags[str2nr(k[strridx(k, "\x01") + 1 :])]})
    call remove(a:tags, 0, -1)
    call extend(a:tags, sorted)
  endif
  for t in a:tags
    if !empty(t.getChildren())
      call tagbar#sorting#sort(t.getChildren(), a:compareby, a:compare_typeinfo)
    endif
  endfor
endfunction
