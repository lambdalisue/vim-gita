let s:V = gita#vital()
let s:File = s:V.import('System.File')
let s:Prompt = s:V.import('Vim.Prompt')

function! s:diffoff() abort
  if !&diff
    return
  endif
  augroup vim_gita_internal_util_diffthis
    autocmd! * <buffer>
  augroup END
  if maparg('<C-l>', 'n') ==# '<Plug>(gita-C-l)'
    unmap <buffer> <C-l>
  endif
  nunmap <buffer> <Plug>(gita-C-l)
  diffoff
endfunction

function! gita#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! gita#util#browse(uri) abort
  call s:File.open(a:uri)
endfunction

function! gita#util#doautocmd(name, ...) abort
  let pattern = get(a:000, 0, '')
  let expr = empty(pattern)
        \ ? '#' . a:name
        \ : '#' . a:name . '#' . pattern
  let eis = split(&eventignore, ',')
  if index(eis, a:name) >= 0 || index(eis, 'all') >= 0 || !exists(expr)
    " the specified event is ignored or not exists
    return
  endif
  let nomodeline = has('patch-7.4.438') && a:name ==# 'User'
        \ ? '<nomodeline> '
        \ : ''
  execute 'doautocmd ' . nomodeline . a:name . ' ' . pattern
endfunction

function! gita#util#diffthis() abort
  if maparg('<C-l>', 'n') ==# ''
    nmap <buffer> <C-l> <Plug>(gita-C-l)
  endif
  nnoremap <buffer><silent> <Plug>(gita-C-l)
        \ :<C-u>diffupdate<BAR>redraw<CR>

  augroup vim_gita_internal_util_diffthis
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diffoff()
    autocmd BufHidden <buffer> call s:diffoff()
  augroup END
  diffthis
  keepjump normal! zM
endfunction

function! gita#util#handle_exception() abort
  let known_attention_patterns = [
        \ '^\%(vital: Git[:.]\|vim-gita:\) Cancel: ',
        \ '^\%(vital: Git[:.]\|vim-gita:\) Attention: ',
        \]
  for pattern in known_attention_patterns
    if v:exception =~# pattern
      call s:Prompt.attention(
            \ 'gita:',
            \ substitute(v:exception, pattern, '', ''),
            \)
      return
    endif
  endfor
  let known_warning_patterns = [
        \ '^\%(vital: Git[:.]\|vim-gita:\) \zeWarning: ',
        \ '^\%(vital: Git[:.]\|vim-gita:\) \zeValidationError: ',
        \]
  for pattern in known_warning_patterns
    if v:exception =~# pattern
      call s:Prompt.warn(
            \ 'gita:',
            \ substitute(v:exception, pattern, '', ''),
            \)
      return
    endif
  endfor
  call s:Prompt.error(v:exception)
  call s:Prompt.debug(v:throwpoint)
endfunction
