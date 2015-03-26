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

function! s:get_hooks(name, timing) abort " {{{
  return get(get(get(g:, 'gita#hooks', {}), a:name, {}), a:timing, [])
endfunction " }}}
function! s:add_hooks(name, timing, hooks) abort " {{{
  if !has_key(g:, 'gita#hooks')
    let g:gita#hooks = {}
  endif
  if !has_key(g:gita#hooks, a:name)
    let g:gita#hooks[a:name] = {}
  endif
  if !has_key(g:gita#hooks[a:name], a:timing)
    let g:gita#hooks[a:name][a:timing] = []
  endif
  let hooks = gita#util#is_list(a:hooks) ? a:hooks : [a:hooks]
  let g:gita#hooks[a:name][a:timing] += hooks
endfunction " }}}
function! s:call_hooks(name, timing, ...) abort " {{{
  let hooks = get(get(get(g:, 'gita#hooks', {}), a:name, {}), a:timing, [])
  for hook in hooks
    call call(hook, a:000)
  endfor
endfunction " }}}

function! s:GitaStatus(opts) abort " {{{
  call gita#ui#status#status_open(a:opts)
endfunction " }}}
function! s:GitaCommit(opts) abort " {{{r
  call gita#ui#status#commit_open(a:opts)
endfunction " }}}
function! s:GitaDiff(opts) abort " {{{
  let commit = empty(get(a:opts, '__unknown__', [])) ? '' : join(a:opts.__unknown__)
  call gita#ui#diff#diffthis(commit, a:opts)
endfunction " }}}
function! s:GitaDefault(opts) abort " {{{
  let git = s:Git.find(expand('%'))
  call s:call_hooks(a:opts._name, 'pre', a:opts)
  let result = git.exec(a:opts.args)
  if result.status == 0
    call gita#util#info(
          \ result.stdout,
          \ printf('Ok: "%s"', join(result.args))
          \)
    call s:call_hooks(a:opts._name, 'post', a:opts)
  else
    call gita#util#info(
          \ result.stdout,
          \ printf('No: "%s"', join(result.args))
          \)
  endif
endfunction " }}}


" Public
function! gita#add_hooks(...) abort " {{{
  call call('s:add_hooks', a:000)
endfunction " }}}
function! gita#get_hooks(...) abort " {{{
  return call('s:get_hooks', a:000)
endfunction " }}}
function! gita#call_hooks(...) abort " {{{
  return call('s:call_hooks', a:000)
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

let s:gita = {}
function! gita#get() abort " {{{
  let bufname = bufname('%')
  let gita = get(b:, '_gita', {})
  if empty(gita) || (empty(&buftype) && bufname !=# gita.bufname) || (get(g:, 'gita#debug', 0) && empty(&buftype))
    if strlen(&buftype)
      let gita = extend(deepcopy(s:gita), {
            \ 'bufname': bufname,
            \ 'is_enable': 0,
            \ 'git': {},
            \})
    else
      let git = s:Git.find(bufname)
      let gita = extend(deepcopy(s:gita), {
            \ 'bufname': bufname,
            \ 'is_enable': !empty(git),
            \ 'git': git,
            \})
    endif
  endif
  " cache gita instance
  call gita#set(gita)
  return gita
endfunction " }}}
function! gita#set(gita) abort " {{{
  let b:_gita = a:gita
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
