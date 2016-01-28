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
  let known_warning_patterns = [
        \ '^vim-hita: Cancel:',
        \ '^vim-hita: Warning:',
        \]
  for pattern in known_warning_patterns
    if a:exception =~# pattern
      redraw
      call hita#util#prompt#warn(substitute(a:exception, pattern, '', ''))
      return
    endif
  endfor
  let known_exception_patterns = [
        \ '^vim-hita:',
        \ '^vital: Git[:.]',
        \ 'ValidationError:',
        \]
  for pattern in known_exception_patterns
    if a:exception =~# pattern
      redraw
      call hita#util#prompt#error(a:exception)
      return
    endif
  endfor
  throw a:exception
endfunction
