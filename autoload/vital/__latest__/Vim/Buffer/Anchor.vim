let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort " {{{
  let s:Dict = a:V.import('Data.Dict')
  let s:Compat = a:V.import('Vim.Compat')
  let s:config = {
        \ 'buflisted_required': 1,
        \ 'unsuitable_buftype_pattern': '^\%(nofile\|quickfix\)$',
        \ 'unsuitable_bufname_pattern': '',
        \ 'unsuitable_filetype_pattern': '',
        \}
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Data.Dict',
        \ 'Vim.Compat',
        \]
endfunction " }}}

function! s:get_config() abort
  return copy(s:config)
endfunction

function! s:set_config(config) abort
  let s:config = extend(s:config, s:Dict.pick(a:config, [
        \ 'buflisted_required',
        \ 'unsuitable_buftype_pattern',
        \ 'unsuitable_bufname_pattern',
        \ 'unsuitable_filetype_pattern',
        \]))
endfunction

function! s:is_suitable(winnum) abort
  let bufnum  = winbufnr(a:winnum)
  if s:config.buflisted_required && !buflisted(bufnum)
    return 0
  endif
  if !empty(s:config.unsuitable_bufname_pattern)
        \ && bufname(bufnum) =~# s:config.unsuitable_bufname_pattern
    return 0
  endif
  if !empty(s:config.unsuitable_buftype_pattern)
        \ && s:Compat.getbufvar(bufnum, '&buftype') =~# s:config.unsuitable_buftype_pattern
    return 0
  endif
  if !empty(s:config.unsuitable_filetype_pattern)
        \ && s:Compat.getbufvar(bufnum, '&filetype') =~# s:config.unsuitable_filetype_pattern
    return 0
  endif
  return 1
endfunction
function! s:find_suitable(winnum) abort
  if winnr('$') == 1
    return 0
  endif
  " find a suitable window in rightbelow from a previous window
  for winnum in range(a:winnum, winnr('$'))
    if s:is_suitable(winnum)
      return winnum
    endif
  endfor
  " find a suitable window in leftabove to before a previous window
  for winnum in range(1, a:winnum - 1)
    if s:is_suitable(winnum)
      return winnum
    endif
  endfor
  " no suitable window is found.
  return 0
endfunction
function! s:focus() abort
  " find suitable window from the previous window
  let previous_winnum = winnr('#')
  let suitable_winnum = s:find_suitable(previous_winnum)
  let suitable_winnum = suitable_winnum == 0
        \ ? previous_winnum
        \ : suitable_winnum
  silent execute printf('keepjumps %dwincmd w', suitable_winnum)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
