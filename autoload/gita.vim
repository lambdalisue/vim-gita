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

let s:Git = gita#util#import('VCS.Git')


function! s:GitaStatus(opts) abort " {{{
  call gita#core#status_open(a:opts)
endfunction " }}}
function! s:GitaDefault(opts) abort " {{{
  let git = s:Git.find(expand('%'))
  let result = git.exec(a:opts.args)
  if result.status == 0
    call gita#util#info(
          \ result.stdout,
          \ printf('Ok: "%s"', join(result.args))
          \)
  else
    call gita#util#info(
          \ result.stdout,
          \ printf('No: "%s"', join(result.args))
          \)
  endif
endfunction " }}}

function! gita#Gita(opts) abort " {{{
  if empty(a:opts)
    " validation failed
    return
  endif
  if a:opts._name == 'status'
    return s:GitaStatus(a:opts)
  else
    return s:GitaDefault(a:opts)
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
  let g:gita#cors#opener_aliases = extend(
        \ s:default_opener_aliases,
        \ get(g:, 'gita#core#opener_aliases', {}),
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
  let const.interface_pattern = printf('\v%%(%s|%s)',
        \ const.status_bufname,
        \ const.commit_bufname,
        \)
  lockvar const
  let g:gita#core#const = const
endfunction
call s:assign_consts() "}}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
