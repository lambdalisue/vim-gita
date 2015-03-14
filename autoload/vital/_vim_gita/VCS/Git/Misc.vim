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
  let s:Git          = a:V.import('VCS.Git')
  let s:StatusParser = a:V.import('VCS.Git.StatusParser')
  let s:ConfigParser = a:V.import('VCS.Git.ConfigParser')

  let s:config = deepcopy(s:Git.config)
  let self.config = s:config
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'VCS.Git.StatusParser',
        \ 'VCS.Git.ConfigParser',
        \]
endfunction " }}}

function! s:count_commits_ahead_of_remote(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let result = s:Git.exec(['log', '--oneline', '@{upstream}..'], opts)
  return result.status == 0 ? len(split(result.stdout, '\v%(\r?\n)')) : 0
endfunction " }}}
function! s:count_commits_behind_remote(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let result = s:Git.exec(['log', '--oneline', '..@{upstream}'], opts)
  return result.status == 0 ? len(split(result.stdout, '\v%(\r?\n)')) : 0
endfunction " }}}

function! s:get_local_branch_name(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  return s:Git.exec_line(['rev-parse', '--abbrev-ref', 'HEAD'], opts)
endfunction " }}}
function! s:get_remote_branch_name(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  " it seems the following is faster than 'rev-parse --abbrev-ref --symbolic-full-name @{u}'
  " ref: http://stackoverflow.com/questions/171550/find-out-which-remote-branch-a-local-branch-is-tracking
  let symbolic_ref = s:Git.exec_line([
        \ 'symbolic-ref', '-q', 'HEAD'
        \], opts)
  let remote_name = s:Git.exec_line([
        \ 'for-each-ref', '--format="%(upstream:short)"', symbolic_ref
        \], opts)
  return remote_name
endfunction " }}}

function! s:get_parsed_status(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let result = s:Git.exec(['status', '--porcelain'], opts)
  if result.status != 0
    return {}
  endif
  return s:StatusParser.parse(result.stdout)
endfunction " }}}
function! s:get_parsed_config(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path, 'scope': '' }, get(a:000, 1, {}))
  if opts.scope ==# ''
    let result = s:Git.exec(['config', '-l'], opts)
  elseif opts.scope == 'local'
    let result = s:Git.exec(['config', '-l', '--local'], opts)
  elseif opts.scope == 'global'
    let result = s:Git.exec(['config', '-l', '--global'], opts)
  elseif opts.scope == 'system'
    let result = s:Git.exec(['config', '-l', '--system'], opts)
  else
    throw printf('VCS.Git.Misc: unknown scope "%s" is specified.', opts.scope)
  endif
  if result.status != 0
    return {}
  endif
  return s:ConfigParser.parse(result.stdout)
endfunction " }}}

function! s:get_last_commit_hashref(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path, 'short': 0 }, get(a:000, 1, {}))
  if opts.short
    return s:Git.exec_line(['rev-parse', '--short', 'HEAD'], opts)
  else
    return s:Git.exec_line(['rev-parse', 'HEAD'], opts)
  endif
endfunction " }}}
function! s:get_last_commit_message(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let result = s:Git.exec(['log', '-1', '--pretty=%B'], opts)
  if result.status != 0
    return ''
  endif
  return result.stdout
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttabb et ai textwidth=0 fdm=marker
