let s:save_cpo = &cpo
set cpo&vim

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
  " Note:
  "   git status return UNIX path even in Windows + noshellslash
  let status.path = a:gita.git.get_absolute_path(
        \ gita#utils#ensure_realpath(status.path)
        \)
  if has_key(status, 'path2')
    let status.path2 = a:gita.git.get_absolute_path(
          \ gita#utils#ensure_realpath(status.path2)
          \)
  endif
  let status._gita_extended = 1
  return status
endfunction " }}}
function! gita#utils#status#parse(stdout, ...) abort " {{{
  let statuses = s:S.parse(a:stdout, get(a:000, 0, {}))
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
  let abspath = gita#utils#ensure_abspath(a:path)
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

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
