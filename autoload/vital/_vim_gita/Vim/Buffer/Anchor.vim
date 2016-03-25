let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort
  let s:Dict = a:V.import('Data.Dict')
  let s:Compat = a:V.import('Vim.Compat')
  let s:config = {
        \ 'buflisted_required': 1,
        \ 'unsuitable_buftype_pattern': '^\%(nofile\|quickfix\)$',
        \ 'unsuitable_bufname_pattern': '',
        \ 'unsuitable_filetype_pattern': '',
        \}
endfunction

function! s:_vital_depends() abort
  return [
        \ 'Data.Dict',
        \ 'Vim.Compat',
        \]
endfunction

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

function! s:is_available(opener) abort
  if a:opener =~# '\%(^\|\W\)\%(pta\|ptag\)!\?\%(\W\|$\)'
    return 0
  elseif a:opener =~# '\%(^\|\W\)\%(ped\|pedi\|pedit\)!\?\%(\W\|$\)'
    return 0
  elseif a:opener =~# '\%(^\|\W\)\%(ps\|pse\|psea\|psear\|psearc\|psearch\)!\?\%(\W\|$\)'
    return 0
  elseif a:opener =~# '\%(^\|\W\)\%(tabe\|tabed\|tabedi\|tabedit\|tabnew\)\%(\W\|$\)'
    return 0
  elseif a:opener =~# '\%(^\|\W\)\%(tabf\|tabfi\|tabfin\|tabfind\)\%(\W\|$\)'
    return 0
  endif
  return 1
endfunction

function! s:is_suitable(winnum) abort
  let bufnum  = winbufnr(a:winnum)
  if empty(bufname(bufnum))
    return 1
  elseif s:config.buflisted_required && !buflisted(bufnum)
    return 0
  elseif !empty(s:config.unsuitable_bufname_pattern)
        \ && bufname(bufnum) =~# s:config.unsuitable_bufname_pattern
    return 0
  elseif !empty(s:config.unsuitable_buftype_pattern)
        \ && s:Compat.getbufvar(bufnum, '&buftype') =~# s:config.unsuitable_buftype_pattern
    return 0
  elseif !empty(s:config.unsuitable_filetype_pattern)
        \ && s:Compat.getbufvar(bufnum, '&filetype') =~# s:config.unsuitable_filetype_pattern
    return 0
  endif
  return 1
endfunction

function! s:find_suitable(winnum, ...) abort
  if winnr('$') == 1
    return 1
  endif
  let rangeset = get(a:000, 0, 0)
        \ ? [reverse(range(1, a:winnum)), reverse(range(a:winnum + 1, winnr('$')))]
        \ : [range(a:winnum, winnr('$')), range(1, a:winnum - 1)]
  " find a suitable window in rightbelow from a previous window
  for winnum in rangeset[0]
    if s:is_suitable(winnum)
      return winnum
    endif
  endfor
  if a:winnum > 1
    " find a suitable window in leftabove to before a previous window
    for winnum in rangeset[1]
      if s:is_suitable(winnum)
        return winnum
      endif
    endfor
  endif
  " no suitable window is found.
  return 0
endfunction

function! s:focus(...) abort
  " find suitable window from the previous window
  let previous_winnum = winnr('#')
  let suitable_winnum = s:find_suitable(previous_winnum, get(a:000, 0, 0))
  let suitable_winnum = suitable_winnum == 0
        \ ? previous_winnum
        \ : suitable_winnum
  silent execute printf('keepjumps %dwincmd w', suitable_winnum)
endfunction

function! s:attach() abort
  augroup vital_vim_buffer_anchor_internal
    autocmd! *
    autocmd WinLeave <buffer> call s:_on_WinLeave()
    autocmd WinEnter * call s:_on_WinEnter()
  augroup END
endfunction

function! s:_on_WinLeave() abort
  let g:_vital_vim_buffer_anchor_winleave = winnr('$')
endfunction

function! s:_on_WinEnter() abort
  if exists('g:_vital_vim_buffer_anchor_winleave')
    let nwin = g:_vital_vim_buffer_anchor_winleave
    if winnr('$') < nwin
      call s:focus(1)
    endif
    unlet g:_vital_vim_buffer_anchor_winleave
  endif
  " remove autocmd
  augroup vital_vim_buffer_anchor_internal
    autocmd! *
  augroup END
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo