let s:V = gita#vital()
let s:File = s:V.import('System.File')
let s:Console = s:V.import('Vim.Console')

function! s:diffoff() abort
  if !&diff
    return
  endif
  augroup gita_internal_util_diffthis
    autocmd! * <buffer>
  augroup END
  if maparg('<C-l>', 'n') ==# '<Plug>(gita-C-l)'
    unmap <buffer> <C-l>
  endif
  nunmap <buffer> <Plug>(gita-C-l)
  diffoff
endfunction

function! s:syncbind() abort
  augroup gita_internal_util_syncbind
    autocmd! *
  augroup END
  syncbind
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
  let is_pseudo_required = empty(pattern) && !exists('#' . a:name . '#*')
  if is_pseudo_required
    " NOTE:
    " autocmd XXXXX <pattern> exists but not sure if current buffer name
    " match with the <pattern> so register empty autocmd to prevent
    " 'No matching autocommands' warning
    augroup gita_internal_util_doautocmd
      autocmd! *
      execute 'autocmd ' . a:name . ' * :'
    augroup END
  endif
  let nomodeline = has('patch-7.4.438') && a:name ==# 'User'
        \ ? '<nomodeline> '
        \ : ''
  try
    execute 'doautocmd ' . nomodeline . a:name . ' ' . pattern
  finally
    if is_pseudo_required
      augroup gita_internal_util_doautocmd
        autocmd! *
      augroup END
    endif
  endtry
endfunction

function! gita#util#diffthis() abort
  if maparg('<C-l>', 'n') ==# ''
    nmap <buffer> <C-l> <Plug>(gita-C-l)
  endif
  nnoremap <buffer><silent> <Plug>(gita-C-l)
        \ :<C-u>diffupdate<BAR>redraw<CR>

  augroup gita_internal_util_diffthis
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diffoff()
    autocmd BufHidden   <buffer> call s:diffoff()
  augroup END
  diffoff
  diffthis
  keepjump normal! zM
endfunction

function! gita#util#syncbind() abort
  " NOTE:
  " Somehow syncbind does not just after opening a buffer so use
  " CursorHold and CursorMoved to call a bit later again
  augroup gita_internal_util_syncbind
    autocmd!
    autocmd CursorHold   * call s:syncbind()
    autocmd CursorHoldI  * call s:syncbind()
    autocmd CursorMoved  * call s:syncbind()
    autocmd CursorMovedI * call s:syncbind()
  augroup END
  syncbind
endfunction

function! gita#util#handle_exception() abort
  let known_attention_patterns = [
        \ '^\%(vital: Git[:.]\|gita:\) Cancel: ',
        \ '^\%(vital: Git[:.]\|gita:\) Attention: ',
        \]
  for pattern in known_attention_patterns
    if v:exception =~# pattern
      call s:Console.warn(printf(
            \ 'gita:%s',
            \ substitute(v:exception, pattern, '', ''),
            \))
      return
    endif
  endfor
  let known_warning_patterns = [
        \ '^\%(vital: Git[:.]\|gita:\) \zeWarning: ',
        \ '^\%(vital: Git[:.]\|gita:\) \zeValidationError: ',
        \]
  for pattern in known_warning_patterns
    if v:exception =~# pattern
      call s:Console.warn(printf(
            \ 'gita:%s',
            \ substitute(v:exception, pattern, '', ''),
            \))
      return
    endif
  endfor
  call s:Console.error(v:exception)
  call s:Console.debug(v:throwpoint)
endfunction
