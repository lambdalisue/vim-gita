let s:save_cpo = &cpo
set cpo&vim


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
  call filter(candidates, 'len(v:val)')
  call map(candidates, 'substitute(v:val, "\v^..", "", "")')
  call filter(candidates, 'v:val =~# "^" . a:arglead')
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
