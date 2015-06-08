let s:save_cpo = &cpo
set cpo&vim


function! s:get_local_branch_candidates(...) abort " {{{
  let gita = get(a:000, 0, {})
  let gita = empty(gita) ? gita#core#get() : gita
  if !gita.enabled
    return []
  endif
  let result = gita.operations.branch({
        \ 'list': 1,
        \})
  if result.status
    return []
  endif
  let candidates = split(result.stdout, '\v\r?\n')
  call filter(candidates, 'len(v:val)')
  call map(candidates, 'substitute(v:val, ''\v^..'', '''', '''')')
  return candidates
endfunction " }}}
function! s:get_remote_branch_candidates(...) abort " {{{
  let gita = get(a:000, 0, {})
  let gita = empty(gita) ? gita#core#get() : gita
  if !gita.enabled
    return []
  endif
  let result = gita.operations.branch({
        \ 'list': 1,
        \ 'all': 1,
        \})
  if result.status
    return []
  endif
  let candidates = split(result.stdout, '\v\r?\n')
  call filter(candidates, 'len(v:val) && v:val =~# ''\v^..remotes/''')
  call map(candidates, 'substitute(v:val, ''\v^..remotes/'', '''', '''')')
  call map(candidates, 'substitute(v:val, ''\s->\s.*$'', '''', '''')')
  return candidates
endfunction " }}}


function! gita#completes#complete_local_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let candidates = extend(
        \ ['HEAD'],
        \ s:get_local_branch_candidates(),
        \)
  call filter(candidates, 'v:val =~# ''^'' . a:arglead')
  return candidates
endfunction " }}}
function! gita#completes#complete_remote_branch(arglead, cmdline, cursorpos, ...) abort " {{{
  let candidates = extend(
        \ ['HEAD'],
        \ s:get_remote_branch_candidates(),
        \)
  call filter(candidates, 'v:val =~# ''^'' . a:arglead')
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
