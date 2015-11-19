let s:save_cpoptions = &cpoptions
set cpoptions&vim


function! gita#utils#completes#complete_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita = gita#get()
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
  call map(candidates, 'substitute(v:val, ''\C\v%(^..remotes/|^..|\s\-\>\s.*$)'', "", "g")')
  call filter(candidates, 'len(v:val) && v:val =~# "^" . a:arglead')
  return candidates
endfunction " }}}
function! gita#utils#completes#complete_local_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita = gita#get()
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
function! gita#utils#completes#complete_remote_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let gita = gita#get()
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
  call filter(candidates, 'v:val =~# ''\v^..remotes/''')
  call map(candidates, 'substitute(v:val, ''\C\v%(^..remotes/|\s\-\>\s.*$)'', "", "g")')
  call filter(candidates, 'len(v:val) && v:val =~# "^" . a:arglead')
  return candidates
endfunction " }}}
function! gita#utils#completes#complete_staged_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let statuses = gita#utils#status#parse(result.stdout, { 'fail_silently': 1 })
  if get(statuses, 'status')
    return []
  endif
  let candidates = filter(
        \ map(statuses.staged, 'gita#utils#path#unix_relpath(get(v:val, "path2", v:val.path))'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#utils#completes#complete_unstaged_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': 'fail',
        \})
  let statuses = gita#utils#status#parse(result.stdout, { 'fail_silently': 1 })
  if get(statuses, 'status')
    return []
  endif
  let candidates = filter(
        \ map(statuses.unstaged, 'gita#utils#path#unix_relpath(v:val.path)'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#utils#completes#complete_conflicted_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let statuses = gita#utils#status#parse(result.stdout, { 'fail_silently': 1 })
  if get(statuses, 'status')
    return []
  endif
  let candidates = filter(
        \ map(statuses.conflicted, 'gita#utils#path#unix_relpath(v:val.path)'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}
function! gita#utils#completes#complete_untracked_files(arglead, cmdline, cursorpos, ...) abort " {{{
  let result = gita#features#status#exec_cached({
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \}, {
        \ 'echo': '',
        \})
  let statuses = gita#utils#status#parse(result.stdout, { 'fail_silently': 1 })
  if get(statuses, 'status')
    return []
  endif
  let candidates = filter(
        \ map(statuses.untracked, 'gita#utils#path#unix_relpath(v:val.path)'),
        \ 'v:val =~# "^" . a:arglead',
        \)
  return candidates
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
