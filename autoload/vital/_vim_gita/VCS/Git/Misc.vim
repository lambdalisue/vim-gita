"******************************************************************************
" Git misc
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort " {{{
  let s:V = a:V
  let s:Prelude      = a:V.import('Prelude')
  let s:Dict         = a:V.import('Data.Dict')
  let s:Core         = a:V.import('VCS.Git.Core')
  let s:StatusParser = a:V.import('VCS.Git.StatusParser')
  let s:ConfigParser = a:V.import('VCS.Git.ConfigParser')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'Data.Dict',
        \ 'VCS.Git.Core',
        \ 'VCS.Git.StatusParser',
        \ 'VCS.Git.ConfigParser',
        \]
endfunction " }}}

function! s:opts2args(opts, defaults) abort " {{{
  let args = []
  for [key, default] in items(a:defaults)
    if has_key(a:opts, key)
      let val = get(a:opts, key)
      if s:Prelude.is_number(default) && val
        if strlen(key) == 1
          call add(args, printf('-%s', key))
        else
          call add(args, printf('--%s', substitute(key, '_', '-', 'g')))
        endif
      elseif s:Prelude.is_string(default) && default =~# '\v^\=' && default !=# printf('=%s', val)
        if strlen(key) == 1
          call add(args, printf('-%s%s', key, val))
        else
          call add(args, printf('--%s=%s', substitute(key, '_', '-', 'g'), val))
        endif
      elseif s:Prelude.is_string(default) && default !~# '\v^\=' && default !=# val
        if strlen(key) == 1
          call add(args, printf('-%s', key))
        else
          call add(args, printf('--%s', substitute(key, '_', '-', 'g')))
        endif
        call add(args, val)
      endif
      unlet val
    endif
    unlet default
  endfor
  return args
endfunction " }}}

function! s:get_parsed_status(...) " {{{
  let defs = {
        \ 'branch': 0,
        \ 'untracked_files': '=all',
        \ 'ignore_submodules': '=all',
        \ 'ignored': 0,
        \ 'z': 0,
        \} 
  let opts = get(a:000, 0, {})
  let args = ['status', '--porcelain'] + s:opts2args(opts, defs)
  let result = s:Core.exec(args, s:Dict.omit(opts, keys(defs)))
  if result.status != 0
    return result
  endif
  return s:StatusParser.parse(result.stdout, { 'fail_silently': 1 })
endfunction " }}}
function! s:get_parsed_commit(...) " {{{
  let defs = {
        \ 'all': 0,
        \ 'patch': 0,
        \ 'reuse_message': '=',
        \ 'reedit_message': '=',
        \ 'fixup': '=',
        \ 'squash': '=',
        \ 'reset_author': 0,
        \ 'short': 0,
        \ 'z': 0,
        \ 'file': '=',
        \ 'author': '=',
        \ 'date': '=',
        \ 'message': '=',
        \ 'template': '=',
        \ 'signoff': 0,
        \ 'no_verify': 0,
        \ 'allow_empty': 0,
        \ 'allow_empty_message': 0,
        \ 'cleanup': '=default',
        \ 'edit': 0,
        \ 'amend': 0,
        \ 'include': 0,
        \ 'only': 0,
        \ 'untracked_files': '=all',
        \ 'verbose': 0,
        \ 'quiet': 0,
        \ 'status': 0,
        \ 'no_status': 0,
        \} 
  let opts = get(a:000, 0, {})
  let args = ['commit', '--dry-run', '--porcelain'] + s:opts2args(opts, defs)
  let result = s:Core.exec(args, s:Dict.omit(opts, keys(defs)))
  " Note:
  "   I'm not sure but apparently the exit status is 1
  if result.status != 1
    return result
  endif
  return s:StatusParser.parse(result.stdout, { 'fail_silently': 1 })
endfunction " }}}
function! s:get_parsed_config(...) " {{{
  let defs = {
        \ 'local': 0,
        \ 'global': 0,
        \ 'system': 0,
        \ 'file': '',
        \ 'blob': '',
        \ 'bool': 0,
        \ 'int': 0,
        \ 'bool_or_int': 0,
        \ 'path': 0,
        \ 'includes': 0,
        \}
  let opts = get(a:000, 0, {})
  let args = ['config', '--list'] + s:opts2args(opts, defs)
  let result = s:Core.exec(args, s:Dict.omit(opts, keys(defs)))
  if result.status != 0
    return result
  endif
  return s:ConfigParser.parse(result.stdout)
endfunction " }}}

function! s:get_last_commitmsg(...) " {{{
  let opts = get(a:000, 0, {})
  let result = s:Core.exec(['log', '-1', '--pretty=%B'], opts)
  if result.status == 0
    return split(result.stdout, '\v\r?\n')
  else
    return result
  endif
endfunction " }}}
function! s:count_commits_ahead_of_remote(...) " {{{
  let opts = get(a:000, 0, {})
  let result = s:Core.exec(['log', '--oneline', '@{upstream}..'], opts)
  return result.status == 0 ? len(split(result.stdout, '\v%(\r?\n)')) : 0
endfunction " }}}
function! s:count_commits_behind_remote(...) " {{{
  let opts = get(a:000, 0, {})
  let result = s:Core.exec(['log', '--oneline', '..@{upstream}'], opts)
  return result.status == 0 ? len(split(result.stdout, '\v%(\r?\n)')) : 0
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttabb et ai textwidth=0 fdm=marker
