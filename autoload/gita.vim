"******************************************************************************
" Another Git manipulation plugin
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! gita#Gita(options) abort " {{{
  if empty(a:options)
    " validation failed.
    return
  endif
endfunction " }}}
function! gita#define_highlights() abort " {{{
  highlight default link GitaTitle              Title
  highlight default link GitaError              ErrorMsg
  highlight default link GitaWarning            WarningMsg
  highlight default link GitaInfo               Comment
  highlight default link GitaQuestion           Question
endfunction " }}}
function! gita#define_syntax() abort " {{{
endfunction " }}}


" Variables {{{
let s:default_openers = {
      \ 'edit': 'edit',
      \ 'split': 'rightbelow split',
      \ 'vsplit': 'rightbelow vsplit',
      \}
let s:settings = {
      \ 'status_opener': '"topleft 20 split +set\\ winfixheight"',
      \ 'status_default_opener': '"edit"',
      \ 'status_default_opener_in_action': '"edit"',
      \ 'close_status_after_open': 0,
      \ 'enable_default_keymaps': 1,
      \}
function! s:init() " {{{
  for [key, value] in items(s:settings)
    if !exists('g:gita#' . key)
      execute 'let g:gita#' . key . ' = ' . value
    endif
  endfor
  let g:gita#status_openers = extend(s:default_openers,
        \ get(g:, 'gita#status_openers', {}))
  let g:gita#status_openers_in_action = extend(g:gita#status_openers,
        \ get(g:, 'gita#status_openers_in_action', {}))
endfunction " }}}
call s:init()
call gita#define_highlights()
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
