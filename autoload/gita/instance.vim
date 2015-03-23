"******************************************************************************
" vim-gita instance
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
scriptencoding utf8

let s:save_cpo = &cpo
set cpo&vim

" Vital modules ==============================================================
" {{{
let s:Cache = gita#util#import('System.Cache.Simple')
let s:Git   = gita#util#import('VCS.Git')
" }}}

function! gita#instance#create() " {{{
  let b:gita = extend(s:Cache.new(), deepcopy(s:gita))
  let b:gita.git = s:Git.find(expand('%:p'))
  let b:gita._invoker_bufnum = bufnr('%')
  return b:gita
endfunction " }}}
function! gita#instance#get_or_create() " {{{
  if exists('b:gita')
    return b:gita
  endif
  return gita#instance#create()
endfunction " }}}

let s:gita = {}
function! s:gita.get_invoker_bufnum() " {{{
  return self._invoker_bufnum
endfunction " }}}
function! s:gita.get_invoker_bufname() " {{{
  return bufname(self._invoker_bufnum)
endfunction " }}}
function! s:gita.get_invoker_winnum() " {{{
  return winbufnr(self._invoker_bufnum)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
