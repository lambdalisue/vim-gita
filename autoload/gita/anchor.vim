let s:save_cpo = &cpo
set cpo&vim


function! gita#anchor#is_suitable(winnum) abort " {{{
  let bufnum = winbufnr(a:winnum)
  let bufname = bufname(bufnum)
  let buftype = getbufvar(bufnum, '&l:buftype')
  let filetype = getbufvar(bufnum, '&l:filetype')
  if !empty(buftype) && (
        \ bufname  =~# g:gita#anchor#unsuitable_bufname_pattern ||
        \ filetype =~# g:gita#anchor#unsuitable_filetype_pattern)
    return 0
  else
    return 1
  endif
endfunction " }}}
function! gita#anchor#focus() abort " {{{
  let previous_winnum = winnr('#')
  " find a suitable window in rightbelow from a previous window
  for winnum in range(previous_winnum, winnr('$'))
    if gita#anchor#is_suitable(winnum)
      silent execute printf('%dwincmd w', winnum)
      return
    endif
  endfor
  " find a suitable window in leftabove from a previous window
  for winnum in range(1, previous_winnum - 1)
    if gita#anchor#is_suitable(winnum)
      silent execute printf('%dwincmd w', winnum)
      return
    endif
  endfor
  " no suitable window is found. just use previous window
  silent execute printf('%dwincmd w', previous_winnum)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
