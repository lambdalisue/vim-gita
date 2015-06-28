let s:save_cpo = &cpo
set cpo&vim

function! s:Gita(...) abort " {{{
  call call('gita#features#command', a:000)
endfunction " }}}
function! s:GitaComplete(...) abort " {{{
  return call('gita#features#complete', a:000)
endfunction " }}}

command! -nargs=? -range -bang
      \ -complete=customlist,s:GitaComplete
      \ Gita
      \ :call s:Gita(<q-bang>, [<line1>, <line2>], <f-args>)

" Assign configure variables " {{{
let s:default = {
      \ 'debug': 0,
      \}
function! s:assign_config()
  for [key, default] in items(s:default)
    let g:gita#{key} = get(g:, 'gita#' . key, default)
  endfor
endfunction
call s:assign_config()
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
