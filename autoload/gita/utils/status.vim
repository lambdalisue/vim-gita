let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:S = gita#import('VCS.Git.StatusParser')

function! gita#utils#status#virtual(path, ...) abort " {{{
  let virtual = extend({
        \ 'path': a:path,
        \ 'index':    ' ',
        \ 'worktree': ' ',
        \ 'sign':     '  ',
        \ 'record': printf('   %s', a:path),
        \ 'is_conflict':  0,
        \ 'is_staged':    0,
        \ 'is_unstaged':  0,
        \ 'is_untracked': 0,
        \ 'is_ignored':   0,
        \}, get(a:000, 0, {}))
  return virtual
endfunction " }}}
function! gita#utils#status#extend_status(status, gita, ...) abort " {{{
  " Note:
  "   A command 'git -C <worktree> status --porcelain' always
  "   return a relative path from the repository root
  if get(a:status, '_gita_extended')
    return a:status
  endif
  let options = extend({
        \ 'inplace': 0,
        \}, get(a:000, 0, {}))
  let status = options.inplace ? a:status : deepcopy(a:status)
  " Note: First of all, the followings are requirements
  "
  "   1. 'git status' return an UNIX path even in Windows with noshellslash
  "   2. VCS.Git.get_absolute_path require a REAL path to check if the path
  "      is absolute or not
  "   3. As much as possible, path should be store as an UNIX path
  "
  " Thus follow the following procedures
  "
  "   1. Make sure the path is a real path
  "   2. Make sure the path is an absolute path
  "   3. Make sure the path is an unix path
  "
  let status.path = gita#utils#path#unix_abspath(
        \ a:gita.git.get_absolute_path(
        \   gita#utils#path#real_relpath(status.path)
        \))
  if has_key(status, 'path2')
    let status.path2 = gita#utils#path#unix_abspath(
          \ a:gita.git.get_absolute_path(
          \   gita#utils#path#real_relpath(status.path2)
          \))
  endif
  let status._gita_extended = 1
  return status
endfunction " }}}
function! gita#utils#status#parse(stdout, ...) abort " {{{
  let options = extend({
        \ 'fail_silently': 1,
        \}, get(a:000, 0, {})
        \)
  let statuses = s:S.parse(a:stdout, options)
  if get(statuses, 'status')
    return statuses
  endif
  let gita = a:0 > 1 ? a:1 : gita#get()
  " Note:
  "   statuses in other attributes (e.g. 'staged') are linked to statuses in
  "   'all' attribute thus extend these statuses 'inplace'.
  call map(
        \ statuses.all,
        \ 'gita#utils#status#extend_status(v:val, gita, { "inplace" : 1 })',
        \)
  return statuses
endfunction " }}}
function! gita#utils#status#retrieve(path, ...) abort " {{{
  let gita = gita#get()
  let abspath = gita#utils#path#unix_abspath(a:path)
  let virtual = gita#utils#status#virtual(a:path)
  let options = {
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \ '--': [abspath],
        \}
  let result = gita.operations.status(options, extend({
        \ 'echo': 'fail',
        \}, get(a:000, 0, {})))
  if result.status
    return virtual
  endif
  let statuses = gita#utils#status#parse(result.stdout, {
        \ 'fail_silently': 1,
        \})
  if get(statuses, 'status')
    return virtual
  endif
  return get(statuses.all, 0, virtual)
endfunction " }}}
function! gita#utils#status#extend_candidate(candidate, ...) abort "{{{
  let status = get(a:candidate, 'status', get(a:000, 0, {}))
  let status = empty(status)
        \ ? gita#utils#status#retrieve(a:candidate.path)
        \ : status
  if has_key(status, 'path2') && !has_key(a:candidate, 'realpath')
    let a:candidate.realpath = status.path2
  endif
  let a:candidate.status = status
endfunction " }}}
function! gita#utils#status#sortfn(lhs, rhs) abort " {{{
  if a:lhs.path == a:rhs.path
    return 0
  elseif a:lhs.path > a:rhs.path
    return 1
  else
    return -1
  endif
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
