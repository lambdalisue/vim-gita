let s:V = hita#vital()
let s:Guard = s:V.import('Vim.Guard')
let s:Compat = s:V.import('Vim.Compat')
let s:Prompt = s:V.import('Vim.Prompt')

function! hita#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! hita#util#doautocmd(name, ...) abort
  if !exists('#User#Hita' . a:name)
    return
  endif
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

function! hita#util#handle_exception() abort
  let known_attention_patterns = [
        \ '^\%(vital: Git[:.]\|vim-hita:\) Cancel:',
        \ '^\%(vital: Git[:.]\|vim-hita:\) Attention:',
        \]
  for pattern in known_attention_patterns
    if v:exception =~# pattern
      call s:Prompt.attention(substitute(v:exception, pattern, '', ''))
      return
    endif
  endfor
  let known_warning_patterns = [
        \ '^\%(vital: Git[:.]\|vim-hita:\) \zeWarning:',
        \ '^\%(vital: Git[:.]\|vim-hita:\) \zeValidationError:',
        \]
  for pattern in known_warning_patterns
    if v:exception =~# pattern
      call s:Prompt.warn(substitute(v:exception, pattern, '', ''))
      return
    endif
  endfor
  call s:Prompt.error(v:exception)
  call s:Prompt.debug(v:throwpoint)
endfunction

function! hita#util#define_variables(prefix, defaults) abort
  " Note:
  "   Funcref is not supported while the variable must start with a capital
  let prefix = empty(a:prefix)
        \ ? 'g:hita'
        \ : printf('g:hita#%s', a:prefix)
  for [key, value] in items(a:defaults)
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      execute printf('let %s = %s', name, string(value))
    endif
    unlet value
  endfor
endfunction

function! hita#util#select(selection, ...) abort
  " Original from mattn/emmet-vim
  " https://github.com/mattn/emmet-vim/blob/master/autoload/emmet/util.vim#L75-L79
  let prefer_visual = get(a:000, 0, 0)
  let line_start = get(a:selection, 0, 1)
  let line_end = get(a:selection, 1, line_start)
  if line_start == line_end && !prefer_visual
    keepjump call setpos('.', [0, line_start, 1, 0])
  else
    keepjump call setpos('.', [0, line_end, 1, 0])
    keepjump normal! v
    keepjump call setpos('.', [0, line_start, 1, 0])
  endif
endfunction
