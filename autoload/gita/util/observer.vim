let s:registry = {}
let s:reserved = {}

function! s:is_attached() abort
  let bufnum = string(bufnr('%'))
  return has_key(s:registry, bufnum)
        \ && exists('#gita_internal_util_observer_attach')
endfunction

function! s:_on_BufWinEnter() abort
  let bufnum = string(bufnr('%'))
  if has_key(s:reserved, bufnum)
    unlet s:reserved[bufnum]
    call gita#util#observer#update()
  endif
endfunction

function! gita#util#observer#attach(...) abort
  let s:registry[bufnr('%')] = get(a:000, 0, 'edit')
  augroup gita_internal_util_observer_attach
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested call s:_on_BufWinEnter()
  augroup END
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
    if winnum > 0 && getbufvar(str2nr(bufnum), '&autoread')
      execute printf('noautocmd keepjumps %dwincmd w', winnum)
      call gita#util#observer#update()
    elseif bufexists(str2nr(bufnum))
      let s:reserved[bufnum] = 1
    else
      unlet s:registry[bufnum]
    endif
  endfor
  execute printf('noautocmd keepjumps %dwincmd w', winnum_saved)
endfunction

" Automatically start observation when it's sourced
augroup gita_internal_util_observer
  autocmd! *
  autocmd User GitaStatusModified nested call gita#util#observer#update_all()
augroup END
