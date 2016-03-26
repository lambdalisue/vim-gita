let s:registry = {}

function! s:on_BufWritePre() abort
  if empty(&buftype) && gita#core#get().is_enabled
    let b:_gita_internal_observer_modified = &modified
  endif
endfunction

function! s:on_BufWritePost() abort
  if exists('b:_gita_internal_observer_modified')
    if b:_gita_internal_observer_modified && !&modified
      call gita#util#doautocmd('User', 'GitaStatusModified')
    endif
    unlet b:_gita_internal_observer_modified
  endif
endfunction

function! gita#util#observer#attach(...) abort
  let s:registry[bufnr('%')] = get(a:000, 0, 'edit')
  augroup vim_gita_internal_observer_individual
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested
          \ if exists('b:_gita_internal_observer_update_required') |
          \   silent unlet b:_gita_internal_observer_update_required |
          \   silent call gita#util#observer#update() |
          \ endif
  augroup END
  let b:_gita_internal_observer_attached = 1
endfunction

function! gita#util#observer#detach() abort
  let bufnum  = bufnr('%')
  if has_key(s:registry, bufnum)
    unlet s:registry[bufnum]
    silent! unlet b:_gita_internal_observer_attached
  endif
endfunction

function! gita#util#observer#update() abort
  let bufnum = bufnr('%')
  if has_key(s:registry, bufnum) && exists('b:_gita_internal_observer_attached')
    if &verbose > 0
      echomsg printf('gita: "%s" is performed on "%s"',
            \ s:registry[bufnum],
            \ bufname(bufnum),
            \)
    endif
    execute s:registry[bufnum]
  endif
endfunction

function! gita#util#observer#update_all() abort
  let winnum_saved = winnr()
  let missing_bufnums = []
  for bufnum in keys(s:registry)
    if !bufexists(str2nr(bufnum))
      unlet s:registry[bufnum]
      continue
    endif
    let winnum = bufwinnr(str2nr(bufnum))
    if winnum >= 0
      noautocmd execute printf('keepjumps %dwincmd w', winnum)
      call gita#util#observer#update()
    else
      call setbufvar(str2nr(bufnum), '_gita_internal_observer_update_required', 1)
    endif
  endfor
  noautocmd execute printf('keepjumps %dwincmd w', winnum_saved)
endfunction

" Automatically start observation when it's sourced
augroup vim_gita_internal_observer
  autocmd! *
  autocmd BufWritePre  * call s:on_BufWritePre()
  autocmd BufWritePost * nested call s:on_BufWritePost()
  autocmd User GitaStatusModified nested silent call gita#util#observer#update_all()
augroup END
