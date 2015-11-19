let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! gita#utils#anchor#is_suitable(winnum) abort " {{{
  let bufnum = winbufnr(a:winnum)
  let bufname = bufname(bufnum)
  let buftype = gita#compat#getbufvar(bufnum, '&l:buftype')
  let filetype = gita#compat#getbufvar(bufnum, '&l:filetype')
  if !empty(buftype) && (
        \ bufname  =~# g:gita#utils#anchor#unsuitable_bufname_pattern ||
        \ filetype =~# g:gita#utils#anchor#unsuitable_filetype_pattern)
    return 0
  else
    return 1
  endif
endfunction " }}}
function! gita#utils#anchor#find_suitable(winnum) abort " {{{
  " find a suitable window in rightbelow from a previous window
  for winnum in range(a:winnum, winnr('$'))
    if gita#utils#anchor#is_suitable(winnum)
      return winnum
    endif
  endfor
  " find a suitable window in leftabove from a previous window
  for winnum in range(1, a:winnum - 1)
    if gita#utils#anchor#is_suitable(winnum)
      return winnum
    endif
  endfor
  " no suitable window is found.
  return 0
endfunction " }}}
function! gita#utils#anchor#focus() abort " {{{
  " find suitable window from the previous window
  let previous_winnum = winnr('#')
  let suitable_winnum = gita#utils#anchor#find_suitable(previous_winnum)
  let suitable_winnum = suitable_winnum == 0
        \ ? previous_winnum
        \ : suitable_winnum
  silent execute printf('keepjumps %dwincmd w', suitable_winnum)
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
