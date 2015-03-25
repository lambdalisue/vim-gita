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
  call gita#core#status_open(a:opts)
endfunction " }}}
function! s:GitaCommit(opts) abort " {{{r
  call gita#core#commit_open(a:opts)
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
function! s:opts2args(opts, defaults) abort " {{{
  let args = []
  for [key, value] in items(a:defaults)
    if has_key(a:opts, key)
      let val = get(a:opts, key)
      if gita#util#is_number(val) && val == 1
        call add(args, printf('--%s', substitute(key, '_', '-', 'g')))
      elseif gita#util#is_string(val)
        call add(args, printf('--%s', substitute(key, '_', '-', 'g')))
        call add(args, val)
      endif
      unlet val
    endif
    unlet value
  endfor
  return args
endfunction " }}}
function! s:parse_exec_result(result) abort " {{{
  let cmdline = join(a:result.args)
  if a:result.status == 0
    call gita#util#info(
          \ a:result.stdout,
          \ printf('Ok: %s', cmdline)
          \)
    return 0
  else
    call gita#util#error(
          \ a:result.stdout,
          \ printf('Fail: %s', cmdline)
          \)
    return 1
  endif
endfunction " }}}

" Gita instance
let s:gita = {}
function! s:gita.add(options, ...) abort " {{{
  let defaults = {
        \ 'force': 0,
        \ 'update': 0,
        \ 'all': 0,
        \ 'intent_to_add': 0,
        \ 'ignore_removal': 0,
        \ 'ignore_errors': 0,
        \ 'ignore_missing': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = ['add'] + s:opts2args(a:options, defaults)
  let filenames = gita#util#listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return s:parse_exec_result(self.git.exec(args, opts))
endfunction " }}}
function! s:gita.rm(options, ...) abort " {{{
  let defaults = {
        \ 'force': 0,
        \ 'cached': 0,
        \ 'r': 0,
        \ 'ignore_unmatch': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = ['rm'] + s:opts2args(a:options, defaults)
  let filenames = gita#util#listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return s:parse_exec_result(self.git.exec(args, opts))
endfunction " }}}
function! s:gita.checkout(options, branch, ...) abort " {{{
  let defaults = {
        \ 'b': 0,       " create and checkout a new branch
        \ 'B': 0,       " create/reset and checkout a branch
        \ 'l': 0,       " create reflog for new branch
        \ 'detach': 0,  " detach the HEAD at named commit
        \ 'track': 0,   " set upstream info for new branch
        \ 'ours': 0,    " checkout our version for unmerged files
        \ 'theirs': 0,  " checkout their version for unmerged files
        \ 'force': 0,   " force checkout (throw away local modifications)
        \ 'merge': 0,   " perform a 3-way merge with the new branch
        \ 'orphan': 0, 
        \}
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = ['checkout'] + s:opts2args(a:options, defaults)
  let filenames = gita#util#listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, [a:branch, '--', filenames])
  else
    call add(args, [a:branch])
  endif
  return s:parse_exec_result(self.git.exec(args, opts))
endfunction " }}}
function! s:gita.status(options, ...) abort " {{{
  let defaults = {
        \ 'ignored': 0,
        \ 'untracked_files': 'all',
        \ 'ignore_submodules': 'all',
        \ 'parsed': 0,
        \}
  if get(a:options, 'parsed', 0)
    let parsed = self.git.get_parsed_status(a:options)
    if get(parsed, 'status', 0)
      call gita#util#error(
            \ parsed.stdout,
            \ printf('Fail: %s', join(parsed.args))
            \)
      return {}
    else
      return parsed
    endif
  else
    let opts = s:Dict.omit(a:options, keys(defaults))
    let args = ['status'] + s:opts2args(a:options, defaults)
    let filenames = gita#util#listalize(get(a:000, 0, []))
    if len(filenames) > 0
      call add(args, ['--', filenames])
    endif
    return s:parse_exec_result(self.git.exec(args, opts))
  endif
endfunction " }}}
function! s:gita.commit(options, ...) abort " {{{
  let defaults = {
        \ 'file': 0,
        \ 'author': 0,
        \ 'date': 0,
        \ 'message': 0,
        \ 'reedit_message': 0,
        \ 'reuse_message': 0,
        \ 'fixup': 0,
        \ 'squash': 0,
        \ 'cleanup': 0,
        \ 'gpg_sign': 0,
        \ 'untracked_files': 'all',
        \ 'reset_author': 0,
        \ 'signoff': 0,
        \ 'all': 0,
        \ 'amend': 0,
        \ 'no_post_rewrite': 0,
        \ 'parsed': 0,
        \}
  if get(a:options, 'parsed', 0)
    let parsed = self.git.get_parsed_commit(a:options)
    if get(parsed, 'status', 0)
      call gita#util#error(
            \ parsed.stdout,
            \ printf('Fail: %s', join(parsed.args))
            \)
      return {}
    else
      return parsed
    endif
  else
    let opts = s:Dict.omit(a:options, keys(defaults))
    let args = ['commit'] + s:opts2args(a:options, defaults)
    let filenames = gita#util#listalize(get(a:000, 0, []))
    if len(filenames) > 0
      call add(args, ['--', filenames])
    endif
    return s:parse_exec_result(self.git.exec(args, opts))
  endif
endfunction " }}}

" Public
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
  else
    return s:GitaDefault(a:opts)
  endif
endfunction " }}}
function! gita#get(...) abort " {{{
  let bufname = bufname(get(a:000, 0, '%'))
  let gita = getbufvar(bufname, '_gita', {})
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
  call gita#set(gita, bufname)
  return gita
endfunction " }}}
function! gita#set(gita, ...) abort " {{{
  let bufname = get(a:000, 0, '%')
  call setbufvar(bufname, '_gita', a:gita)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
