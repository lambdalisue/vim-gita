"******************************************************************************
" Another Git manipulation plugin
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:Gita(...) " {{{
  return gita#Gita(call("gita#arguments#parse", a:000))
endfunction " }}}
function! s:GitaComplete(...) " {{{
  return call("gita#arguments#complete", a:000)
endfunction " }}}


command! -nargs=? -range=% -bang
      \ -complete=customlist,s:GitaComplete Gita
      \ :call s:Gita(<q-bang>, [<line1>, <line2>], <f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
