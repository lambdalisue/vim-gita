let s:registry = {}

function! s:is_attached() abort
  let bufnum = string(bufnr('%'))
  return has_key(s:registry, bufnum) && exists('b:_gita_observer_attached')
endfunction

function! s:_on_WinEnter() abort
  augroup gita_internal_util_observer_attach
    autocmd! * <buffer>
  augroup END
  call gita#util#observer#update()
endfunction

function! gita#util#observer#attach(...) abort
  let s:registry[bufnr('%')] = get(a:000, 0, 'edit')
  let b:_gita_observer_attached = 1
endfunction

function! gita#util#observer#update() abort
  let bufnum = string(bufnr('%'))
  if s:is_attached()
    if &verbose > 0
      echomsg printf('gita: observer: "%s" is performed on "%s"',
            \ s:registry[bufnum],
            \ bufname('%'),
            \)
    endif
    execute s:registry[bufnum]
  endif
endfunction

function! gita#util#observer#update_all() abort
  let winnum_saved = winnr()
  for bufnum in keys(s:registry)
    let winnum = bufwinnr(str2nr(bufnum))
    if winnum > 0
      execute printf('noautocmd keepjumps %dwincmd w', winnum)
      call gita#util#observer#update()
    elseif bufexists(str2nr(bufnum))
      augroup gita_internal_util_observer_attach
        execute printf('autocmd! * <buffer=%s>', bufnum)
        execute printf(
              \ 'autocmd WinEnter <buffer=%s> nested call s:_on_WinEnter()',
              \ bufnum
              \)
        execute printf(
              \ 'autocmd BufWinEnter <buffer=%s> nested call s:_on_WinEnter()',
              \ bufnum
              \)
      augroup END
    else
      unlet s:registry[bufnum]
    endif
  endfor
  execute printf('noautocmd keepjumps %dwincmd w', winnum_saved)
endfunction

" Automatically start observation when it's sourced
augroup gita_internal_util_observer
  autocmd! *
  autocmd User GitaStatusModifiedPost nested call gita#util#observer#update_all()
augroup END
