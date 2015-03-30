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

let s:Dict = gita#util#import('Data.Dict')
let s:Git = gita#util#import('VCS.Git')

function! s:GitaStatus(opts) abort " {{{
  call gita#interface#status#open(a:opts)
endfunction " }}}
function! s:GitaCommit(opts) abort " {{{
  call gita#interface#commit#open(a:opts)
endfunction " }}}
function! s:GitaDiff(opts) abort " {{{
  let commit = empty(get(a:opts, '__unknown__', [])) ? '' : join(a:opts.__unknown__)
  if get(a:opts, 'compare', 1)
    call gita#interface#diff#compare(expand('%'), commit, a:opts)
  else
    call gita#interface#diff#open(expand('%'), commit, a:opts)
  endif
endfunction " }}}
function! s:GitaDefault(opts) abort " {{{
  let git    = s:Git.find(expand('%'))
  let result = git.exec(a:opts.args)
  if result.status == 0
    call gita#util#info(
          \ result.stdout,
          \ printf('Ok: "%s"', join(result.args))
          \)
    call gita#util#doautocmd(a:opts._name . '-post')
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
  let name = get(a:opts, '_name', '')
  if name ==# 'status'
    return s:GitaStatus(a:opts)
  elseif name ==# 'commit'
    return s:GitaCommit(a:opts)
  elseif name ==# 'diff'
    return s:GitaDiff(a:opts)
  else
    return s:GitaDefault(a:opts)
  endif
endfunction " }}}

function! gita#get(...) abort " {{{
  let bufname = get(a:000, 0, bufname('%'))
  if bufexists(bufname)
    let bufnum  = bufnr(bufname)
    let buftype = getbufvar(bufnum, '&buftype')
    let gita    = getbufvar(bufnum, '_gita', {})
    if empty(gita) || (empty(buftype) && bufname !=# gita.bufname)
      if empty(buftype)
        let git = s:Git.find(fnamemodify(bufname, ':p'))
        let gita = extend(deepcopy(s:gita), {
              \ 'enabled': !empty(git),
              \ 'bufname': bufname,
              \ 'git': git,
              \})
      else
        " Not a file
        let gita = extend(deepcopy(s:gita), {
              \ 'enabled': 0,
              \ 'bufname': bufname,
              \ 'git': {},
              \})
      endif
      call gita#set(gita, bufname)
    endif
  else
    let git = s:Git.find(fnamemodify(bufname, ':p'))
    let gita = extend(deepcopy(s:gita), {
          \ 'enabled': !empty(git),
          \ 'bufname': bufname,
          \ 'git': git,
          \})
  endif
  return gita
endfunction " }}}
function! gita#set(gita, ...) abort " {{{
  let bufname = get(a:000, 0, bufname('%'))
  if bufexists(bufname)
    let bufnum  = bufnr(bufname)
    call setbufvar(bufnum, '_gita', a:gita)
  endif
endfunction " }}}

let s:gita = {}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
