let s:save_cpo = &cpo
set cpo&vim

function! s:hint_status_staged(...) abort " {{{
  let statuses_map = get(w:, '_gita_statuses_map', {})
  let n = 0
  for status in values(statuses_map)
    if status.is_staged
      let n += 1
    endif
  endfor
  if n
    return [
          \ printf('Hint: You have %d staged files. Hit >> to unstage, cc to open commit window.', n),
          \]
  else
    return []
  endif
endfunction " }}}
function! s:hint_status_unstaged(...) abort " {{{
  let statuses_map = get(w:, '_gita_statuses_map', {})
  let n = 0
  for status in values(statuses_map)
    if status.is_unstaged
      let n += 1
    endif
  endfor
  if n
    return [
          \ printf('Hint: You have %d unstaged files. Hit << to stage, dd/DD to see the difference.', n),
          \]
  else
    return []
  endif
endfunction " }}}


function! gita#hint#show(name, ...) abort " {{{
  if !g:gita#hint#enable || !get(g:, 'gita#hint#enable_' . a:name, 1)
    return []
  else
    return call('s:hint_' . a:name, a:000)
  endif
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
