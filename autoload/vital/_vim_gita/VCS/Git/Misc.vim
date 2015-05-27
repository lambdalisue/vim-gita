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

function! s:get_parsed_status(...) " {{{
  let opts = get(a:000, 0, {})
  let args = ['status', '--porcelain'] + get(opts, 'args', [])
  let result = s:Core.exec(args, opts)
  if result.status != 0
    return result
  endif
  return s:StatusParser.parse(result.stdout, { 'fail_silently': 1 })
endfunction " }}}
function! s:get_parsed_commit(...) " {{{
  let opts = get(a:000, 0, {})
  let args = ['commit', '--dry-run', '--porcelain', '--no-status'] + get(opts, 'args', [])
  let result = s:Core.exec(args, opts)
  " Note:
  "   I'm not sure but apparently the exit status is 1
  if result.status != 1
    return result
  endif
  return s:StatusParser.parse(result.stdout, { 'fail_silently': 1 })
endfunction " }}}
function! s:get_parsed_config(...) " {{{
  let opts = get(a:000, 0, {})
  let args = ['config', '--list'] + get(opts, 'args', [])
  let result = s:Core.exec(args, opts)
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
