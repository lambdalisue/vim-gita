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

" Vital {{{
let s:Git = gita#util#import('VCS.Git')
" }}}

function! s:call_hooks(hooks, ...) abort " {{{
  for hook in a:hooks
    call call(hook, a:000)
  endfor
endfunction " }}}
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
  let worktree_path = s:Git.get_worktree_path(expand('%'))
  let fargs = a:options.__shellwords__
  let result = call(s:Git[cname], [fargs, { 'cwd': worktree_path }], s:Git)
  if result.status == 0
    redraw
    call gita#util#info(
          \ result.stdout,
          \ printf('OK: git %s %s', cname, join(fargs)),
          \)
    if has_key(g:gita#interface#hooks, 'post_' . cname)
      call s:call_hooks(get(g:gita#interface#hooks, 'post_' . cname))
    endif
  else
    redraw
    call gita#util#info(
          \ result.stdout,
          \ printf('Fail: git %s %s', cname, join(fargs)),
          \)
  endif
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

  let s:default_interface_hooks = {}
  let s:default_interface_hooks.post_status_update = ['gita#statusline#clean']
  let s:default_interface_hooks.post_commit_update = []
  let s:default_interface_hooks.post_commit = []
  let s:default_interface_hooks.post_fetch = ['gita#statusline#clean']
  let s:default_interface_hooks.post_push = ['gita#statusline#clean']
  let s:default_interface_hooks.post_pull = ['gita#statusline#clean']
  let g:gita#interface#hooks = extend(
        \ s:default_interface_hooks,
        \ get(g:, 'gita#interface#hooks', {}),
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
