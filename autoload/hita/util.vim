let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Compat = s:V.import('Vim.Compat')

function! hita#util#doautocmd(name) abort
  let expr = printf('User Hita%s', a:name)
  call s:Compat.doautocmd(expr, 1)
endfunction
function! hita#util#handle_exception(exception) abort
  redraw
  let known_exception_patterns = [
        \ '^vim-hita: Cancel',
        \ '^vim-hita: Login canceled',
        \ '^vim-hita: ValidationError:',
        \]
  for pattern in known_exception_patterns
    if a:exception =~# pattern
      call hita#util#prompt#warn(matchstr(a:exception, '^vim-hita: \zs.*'))
      return
    endif
  endfor
  call hita#util#prompt#error(a:exception)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
