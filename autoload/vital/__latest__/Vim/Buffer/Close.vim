let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:_ac_QuitPre() abort
  let w:_vital_Vim_Buffer_Close_QuitPre = 1
endfunction
function! s:_ac_QuitPreVim703(name) abort
  if histget('cmd') =~# '^\%(q\|qu\|qui\|quit\|quit!\)$'
    let w:_vital_Vim_Buffer_Close_QuitPre = 1
  elseif histget('cmd') =~# '^\%(cq\|cqu\|cqui\|cquit\|cquit!\)$'
    let w:_vital_Vim_Buffer_Close_QuitPre = 1
  elseif histget('cmd') =~# '^\%(wq\|wq!\)$'
    let w:_vital_Vim_Buffer_Close_QuitPre = 1
  elseif histget('cmd') =~# '^\%(x\|xi\|xit\|xit!\)$'
    let w:_vital_Vim_Buffer_Close_QuitPre = 1
  elseif histget('cmd') =~# '^\%(exi\|exit\|exit!\)$'
    let w:_vital_Vim_Buffer_Close_QuitPre = 1
  endif
endfunction
function! s:_ac_WinLeave() abort
  if get(w:, '_vital_Vim_Buffer_Close_QuitPre')
    let Callback = b:_vital_Vim_Buffer_Close_callback
    unlet! b:_vital_Vim_Buffer_Close_callback
    augroup vital_Vim_Buffer_Close
      autocmd! * <buffer>
    augroup END
    call call(Callback, [])
  endif
endfunction

function! s:register(callback, ...) abort
  let bufnum = get(a:000, 0, bufnr('%'))
  augroup vital_Vim_Buffer_Close
    execute printf('autocmd! * <buffer=%d>', bufnum)
    if exists('##QuitPre')
      execute printf(
            \ 'autocmd QuitPre <buffer=%d> call s:_ac_QuitPre()',
            \ bufnum
            \)
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
      execute printf(
            \ 'autocmd WinLeave <buffer=%d> call s:_ac_QuitPreVim703()',
            \ bufnum,
            \)
    endif
    execute printf(
          \ 'autocmd WinLeave <buffer=%d> call s:_ac_WinLeave()',
          \ bufnum,
          \)
  augroup END
  call setbufvar(bufnum, '_vital_Vim_Buffer_Close_callback', a:callback)
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
