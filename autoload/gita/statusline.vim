"******************************************************************************
" vim-gita statusline
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
scriptencoding utf8

let s:save_cpo = &cpo
set cpo&vim

" Vital modules ==============================================================
" {{{
let s:Cache         = gita#util#import('System.Cache.Simple')
let s:Git           = gita#util#import('VCS.Git')
let s:GitMisc       = gita#util#import('VCS.Git.Misc')
" }}}

function! s:get_cache(name) " {{{
  let name = printf('_%s_cache', a:name)
  if !exists('s:' . name)
    let s:[name] = s:Cache.new()
  endif
  return s:[name]
endfunction " }}}
function! s:get_worktree_path(path) " {{{
  let s:cache = s:get_cache('worktree')
  let cache_name = strlen(a:path) ? a:path : '<empty>'
  if !s:cache.has(cache_name)
    call s:cache.set(cache_name, s:Git.get_worktree_path(a:path))
  endif
  return s:cache.get(cache_name)
endfunction " }}}
function! s:n2s(number) " {{{
  return a:number ? string(a:number) : ''
endfunction " }}}
function! s:get_status(path) " {{{
  let statuses = s:GitMisc.get_parsed_status(a:path)
  let conflicted = len(statuses.conflicted)
  let untracked = len(statuses.untracked)
  let unstaged = len(statuses.unstaged)
  let added = 0
  let deleted = 0
  let renamed = 0
  let modified = 0
  for status in statuses.staged
    if status.index ==# 'A'
      let added += 1
    elseif status.index ==# 'D'
      let deleted += 1
    elseif status.index ==# 'R'
      let renamed += 1
    else
      let modified += 1
    endif
  endfor
  return {
        \ 'conflicted': s:n2s(conflicted),
        \ 'untracked': s:n2s(untracked),
        \ 'added': s:n2s(added),
        \ 'deleted': s:n2s(deleted),
        \ 'renamed': s:n2s(renamed),
        \ 'modified': s:n2s(modified),
        \ 'unstaged': s:n2s(unstaged),
        \}
endfunction " }}}
function! s:get_info(path) " {{{
  let cache = s:get_cache('info')
  let info = cache.get(a:path, {})
  if getftime(a:path) == get(info, 'access_time', -1)
    return info
  endif
  let info.access_time = getftime(a:path)
  let info.repository_name = fnamemodify(s:Git.get_worktree_path(a:path), ':t')
  let info.local_branch_name = s:GitMisc.get_local_branch_name(a:path)
  let info.remote_branch_name = s:GitMisc.get_remote_branch_name(a:path)
  let info.incoming = s:n2s(s:GitMisc.count_commits_behind_remote(a:path))
  let info.outgoing = s:n2s(s:GitMisc.count_commits_ahead_of_remote(a:path)) 
  let info.hashref = s:GitMisc.get_last_commit_hashref(a:path)
  let info.hashref_short = s:GitMisc.get_last_commit_hashref(a:path, { 'short': 1 })
  let info = extend(info, s:get_status(a:path))
  call cache.set(a:path, info)
  return info
endfunction " }}}

function! gita#statusline#info(...) " {{{
  let path = s:get_worktree_path(get(a:000, 0, expand('%')))
  if strlen(path) == 0
    return {}
  endif
  return s:get_info(path)
endfunction " }}}
function! gita#statusline#clean(...) " {{{
  let path = s:get_worktree_path(get(a:000, 0, expand('%')))
  let cache = s:get_cache('info')
  if strlen(path) == 0
    return
  endif
  call cache.remove(path)
endfunction " }}}
function! gita#statusline#format(format, ...) " {{{
  " format rule:
  "   %{<left>|<right>}<key>
  "     '<left><value><right>' if <value> != ''
  "     ''                     if <value> == ''
  "   %{<left>}<key>
  "     '<left><value>'        if <value> != ''
  "     ''                     if <value> == ''
  "   %{|<right>}<key>
  "     '<value><right>'       if <value> != ''
  "     ''                     if <value> == ''
  let info = get(a:000, 0, gita#statusline#info())
  if empty(info)
    return ''
  endif
  let pattern = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, value] in items(s:format_map)
    let result = get(info, value, '')
    let pat = printf(pattern, key)
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pat, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction
let s:format_map = {
      \ 'lb': 'local_branch_name',
      \ 'rb': 'remote_branch_name',
      \ 'rn': 'repository_name',
      \ 'ic': 'incoming',
      \ 'og': 'outgoing',
      \ 'hr': 'hashref',
      \ 'Hr': 'hashref_short',
      \ 'nc': 'conflicted',
      \ 'nu': 'untracked',
      \ 'na': 'added',
      \ 'nd': 'deleted',
      \ 'nr': 'renamed',
      \ 'nm': 'modified',
      \ 'ns': 'unstaged',
      \}
" }}}
function! gita#statusline#preset(name, ...) " {{{
  let info = get(a:000, 0, gita#statusline#info())
  let format = get(s:preset, a:name, '')
  if strlen(format) == 0
    return ''
  endif
  return gita#statusline#format(format, info)
endfunction
let s:preset = {
      \ 'branch': '⭠ %{|/}rn%lb%{ <> |}rb',
      \ 'commit': '%{#}Hr',
      \ 'status': '%{!| }nc%{+| }na%{-| }nd%{=| }nr%{*| }nm%{~| }ns%{?}nu',
      \ 'traffic': '%{⇡| }og%{⇣}ic'
      \}
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
