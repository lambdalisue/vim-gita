"******************************************************************************
" vim-gita action
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:Git = gita#util#import('VCS.Git')

function! gita#action#add(...) " {{{
  return call(s:Git.add, a:000, s:Git)
endfunction " }}}
function! gita#action#rm(...) " {{{
  return call(s:Git.rm, a:000, s:Git)
endfunction " }}}
function! gita#action#checkout(...) " {{{
  return call(s:Git.rm, a:000, s:Git)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

