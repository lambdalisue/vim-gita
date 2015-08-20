let s:save_cpo = &cpo
set cpo&vim

function! gita#utils#commitish#split(commitish, ...) abort " {{{
  let options = get(a:000, 0, {})
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let rhs = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[2]
    return [ a:commit, empty(rhs) ? 'HEAD' : rhs ]
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[ 1 : 2 ]
    return [ empty(lhs) ? 'HEAD' : lhs, empty(rhs) ? 'HEAD' : rhs ]
  else
    return [ get(options, 'cached') ? 'INDEX' : 'WORKTREE', a:commit ]
  endif
endfunction " }}}
function! gita#utils#commitish#rev_parse(commitish, ...) abort " {{{
  let options = get(a:000, 0, {})
  if a:commit =~# '\v^[^.]*\.\.\.?[^.]*$'
    let [lhs, rhs] = gita#utils#commitish#split(a:commitish, options)
  endif
endfunction " }}}
let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
