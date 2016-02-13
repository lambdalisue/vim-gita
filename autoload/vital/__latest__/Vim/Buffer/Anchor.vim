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
  if empty(bufname(bufnum))
    " An initial buffer
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
  if a:winnum > 1
    " find a suitable window in leftabove to before a previous window
    for winnum in range(1, a:winnum - 1)
      if s:is_suitable(winnum)
        return winnum
      endif
    endfor
  endif
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

function! s:register() abort
  augroup vital_Vim_Buffer_Anchor
    autocmd! * <buffer>
    if exists('##QuitPre')
      autocmd QuitPre  <buffer> call s:_ac_QuitPre()
      autocmd WinLeave <buffer> call s:_ac_WinLeave()
    else
      " Note:
      "
      " QuitPre was introduced since Vim 7.3.544
      " https://github.com/vim-jp/vim/commit/4e7db56d
      "
      " :wq       : QuitPre > BufWriteCmd > WinLeave > BufWinLeave
      " :q        : QuitPre > WinLeave > BufWinLeave
      " :e        : BufWinLeave
      " :wincmd w : WinLeave
      "
      autocmd WinLeave <buffer> call s:_ac_WinLeaveVim703()
    endif
  augroup END
endfunction
function! s:_ac_QuitPre() abort
  let w:_vital_Vim_Buffer_Anchor_QuitPre = 1
endfunction
function! s:_ac_WinLeave() abort
  if get(w:, '_vital_Vim_Buffer_Anchor_QuitPre')
    call s:focus()
  endif
  silent! unlet w:_vital_Vim_Buffer_Anchor_QuitPre
endfunction
function! s:_ac_WinLeaveVim703() abort
  if histget('cmd') =~# '\v^%(q|quit|wq)$'
    call s:focus()
  endif
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
