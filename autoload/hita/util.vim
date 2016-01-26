let s:V = hita#vital()
let s:Guard = s:V.import('Vim.Guard')
let s:Compat = s:V.import('Vim.Compat')

function! hita#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! hita#util#doautocmd(name, ...) abort
  let guard = s:Guard.store('g:hita#avars')
  let g:hita#avars = extend(
        \ get(g:, 'hita#avars', {}),
        \ get(a:000, 0, {})
        \)
  try
    let expr = printf('User Hita%s', a:name)
    call s:Compat.doautocmd(expr, 1)
  finally
    call guard.restore()
  endtry
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
