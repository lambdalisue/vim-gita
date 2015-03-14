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

let s:Git           = gita#util#import('VCS.Git')

function! s:GitaStatus(options) abort " {{{
  call gita#interface#status_open(a:options)
endfunction " }}}
function! s:GitaCommit(options) abort " {{{
  call gita#interface#commit_open(a:options)
endfunction " }}}
function! s:GitaDefault(options) abort " {{{
  let cname = a:options.cname
  if !has_key(s:Git, cname)
    call gita#util#error(
          \ printf('Unknown Git command "%s" was specified', cname),
          \ 'Unknown Git command')
    return
  endif
  call call('s:Git' . cname, [a:options.__shellwords__], s:Git)
endfunction " }}}

function! gita#Gita(options) abort " {{{
  if empty(a:options)
    " validation failed
    return
  endif

  if a:options.cname == 'status'
    return s:GitaStatus(a:options)
  elseif a:options.cname == 'commit'
    return s:GitaCommit(a:options)
  else
    return s:GitaDefault(a:options)
  endif
endfunction " }}}

" Assign configure variables " {{{
function! s:assign_configs()
  let g:gita#debug = get(g:, 'gita#debug', 1)

  let s:default_opener_aliases = {
      \ 'edit':   'edit',
      \ 'split':  'split',
      \ 'vsplit': 'vsplit',
      \ 'left':   'topleft vsplit', 
      \ 'right':  'rightbelow vsplit', 
      \ 'above':  'topleft split', 
      \ 'below':  'rightbelow split', 
      \ 'tabnew': 'tabnew',
      \}
  let g:gita#interface#opener_aliases = extend(
        \ s:default_opener_aliases,
        \ get(g:, 'gita#interface#opener_aliases', {}),
        \)
endfunction
call s:assign_configs() " }}}
" Assign constant variables " {{{
function! s:assign_consts()
  let const = {}
  let const.status_filetype = 'gita-status'
  let const.status_bufname = has('unix') ? 'gita:status' : 'gita_status'
  let const.commit_filetype = 'gita-commit'
  let const.commit_bufname = has('unix') ? 'gita:commit' : 'gita_commit'
  lockvar const
  let g:gita#interface#const = const
endfunction
call s:assign_consts() "}}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
