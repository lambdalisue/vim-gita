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

function! s:get_status(path) " {{{
  let statuses = s:GitMisc.get_parsed_status(a:path)
  let conflicted = len(statuses.conflicted)
  let untracked = len(statuses.untracked)
  let unstaged = len(status.unstaged)
  let added = 0
  let deleted = 0
  let renamed = 0
  let modified = 0
  for status in statuses.staged
    if status.index == 'A'
      let added += 1
    elseif status.index == 'D'
      let deleted += 1
    elseif status.index == 'R'
      let renamed += 1
    else
      let modified += 1
    endif
  endfor
  return {
        \ 'conflicted': conflicted ? conflicted : '',
        \ 'untracked': untracked ? untracked : '',
        \ 'added': added ? added : '',
        \ 'deleted': deleted ? deleted : '',
        \ 'renamed': renamed ? renamed : '',
        \ 'modified': modified ? modified : '',
        \ 'unstaged'; unstaged ? unstaged : '',
        \}
endfunction " }}}
function! s:get_info(path, no_cache) " {{{
  if !s:Git.detect(a:path)
    return {}
  elseif !exists('s:info_cache')
    let s:info_cache = s:Cache.new()
  endif
  let path = s:Git.get_worktree_path(a:path)
  let info = s:info_cache.get(path, {})
  if getftime(path) == get(info, 'access_time', -1) && !a:no_cache
    return info
  endif
  let info.access_time = getftime(path)
  let info.repository_name = fnamemodify(s:Git.get_worktree_path(path), ':t')
  let info.local_branch_name = substitute(s:GitMisc.get_local_branch_name(path), '^"\|"$', '', '')
  let info.remote_branch_name = substitute(s:GitMisc.get_remote_branch_name(path), '^"\|"$', '', '')
  let info.incoming = string(s:GitMisc.count_commits_behind_remote(path))
  let info.outgoing = string(s:GitMisc.count_commits_ahead_of_remote(path)) 
  let info.hashref = s:GitMisc.get_last_commit_hashref(path)
  let info.hashref_short = s:GitMisc.get_last_commit_hashref(path, { 'short': 1 })
  let info = extend(info, s:get_status(path))
  call s:info_cache.set(path, info)
  return info
endfunction " }}}

function! gita#statusline#info(...) " {{{
  let options = extend({
        \ 'path': expand('%'),
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  return s:get_info(options.path, options.no_cache)
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
  let pattern = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, value] in items(s:format_map)
    let result = get(info, value, '')
    let pat = printf(pattern, key)
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pat, repl, 'g')
  endfor
  return str
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
  return gita#statusline#format(s:preset[a:name], info)
endfunction
let s:preset = {
      \ 'branch': '⭠ %{|/}rn%lb',
      \ 'remote': '❖  %{|/}rb%Hr',
      \ 'status': '%{!| }nc%{+| }na%{-| }nd%{=| }nr%{*| }nm%{?}nu',
      \ 'traffic': '%{⇡| }og%{⇣}ic'
      \}
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
