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

function! s:Gita(...) abort " {{{
  return gita#Gita(call('gita#argument#parse', a:000))
endfunction " }}}
function! s:GitaComplete(...) abort " {{{
  return call('gita#argument#complete', a:000)
endfunction " }}}

command! -nargs=? -range -bang
      \ -complete=customlist,gita#features#complete
      \ Gita
      \ :call gita#features#command(<q-bang>, [<line1>, <line2>], <f-args>)

" Assign configure variables " {{{
let s:default = {
      \ 'debug': 0,
      \ 'interface#status#define_default_mappings': 1,
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
