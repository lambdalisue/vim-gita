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
  return gita#Gita(call('gita#arguments#parse', a:000))
endfunction " }}}
function! s:GitaComplete(...) abort " {{{
  return call('gita#arguments#complete', a:000)
endfunction " }}}

command! -nargs=? -range=% -bang
      \ -complete=customlist,s:GitaComplete Gita
      \ :call s:Gita(<q-bang>, [<line1>, <line2>], <f-args>)

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
