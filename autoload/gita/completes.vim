let s:save_cpo = &cpo
set cpo&vim


let s:S = gita#utils#import('VCS.Git.StatusParser')


function! gita#completes#complete_local_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    return []
  endif
  let options = {
        \ 'list': 1,
        \}
  let result = gita.operations.branch(options, {
        \ 'echo': '',
        \})
  if result.status
    return []
  endif
  let candidates = split(result.stdout, '\v\r?\n')
  call map(candidates, 'substitute(v:val, "^..", "", "")')
  call filter(candidates, 'len(v:val) && v:val =~# "^" . a:arglead')
  return candidates
endfunction " }}}
function! gita#completes#complete_remote_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    return []
  endif
  let options = {
        \ 'list': 1,
        \ 'all': 1,
        \}
  let result = gita.operations.branch(options, {
        \ 'echo': '',
        \})
  if result.status
    return []
  endif
  let candidates = split(result.stdout, '\v\r?\n')
  call filter(candidates, 'len(v:val) && v:val =~# "\v^..remotes/"')
  call map(candidates, 'substitute(v:val, "\v%(^..remotes/|\s->\s.*$)", "", "g")')
  call filter(candidates, 'v:val =~# "^" . a:arglead')
  return candidates
endfunction " }}}
function! gita#completes#complete_staged_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let status = s:S.parse(result.stdout, { 'fail_silently': 1 })
  if get(status, 'status', 0)
    return []
  endif
  let candidates = filter(
        \ map(status.staged, 'v:val.path'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#completes#complete_unstaged_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': 'fail',
        \})
  let status = s:S.parse(result.stdout, { 'fail_silently': 1 })
  if get(status, 'status', 0)
    return []
  endif
  let candidates = filter(
        \ map(status.unstaged, 'v:val.path'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#completes#complete_conflicted_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let status = s:S.parse(result.stdout, { 'fail_silently': 1 })
  if get(status, 'status', 0)
    return []
  endif
  let candidates = filter(
        \ map(status.conflicted, 'v:val.path'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#completes#complete_untracked_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let status = s:S.parse(result.stdout, { 'fail_silently': 1 })
  if get(status, 'status', 0)
    return []
  endif
  let candidates = filter(
        \ map(status.untracked, 'v:val.path'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
