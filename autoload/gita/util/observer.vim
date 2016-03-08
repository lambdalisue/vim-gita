let s:registry = {}

function! s:on_BufWritePre() abort
  let b:_gita_internal_observer_modified = &modified
endfunction

function! s:on_BufWritePost() abort
  if exists('b:_gita_internal_observer_modified')
    if b:_gita_internal_observer_modified != &modified && gita#core#get().is_enabled
      call gita#util#doautocmd('User', 'GitaStatusModified')
    endif
    silent unlet b:_gita_internal_observer_modified
  endif
endfunction

function! gita#util#observer#attach(...) abort
  let Command = get(a:000, 0, 'edit')
  let s:registry[bufnr('%')] = Command
  augroup vim_gita_internal_observer_individual
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested
          \ if exists('b:_gita_observer_internal_update_required') |
          \   silent unlet b:_gita_observer_internal_update_required |
          \   call gita#util#observer#update() |
          \ endif
  augroup END
endfunction

function! gita#util#observer#detach() abort
  let bufnum  = bufnr('%')
  if has_key(s:registry, bufnum)
    unlet s:registry[bufnum]
  endif
endfunction

function! gita#util#observer#update() abort
  let bufnum = bufnr('%')
  if has_key(s:registry, bufnum)
    execute s:registry[bufnum]
  endif
endfunction

function! gita#util#observer#update_all() abort
  let winnum_saved = winnr()
  for bufnum in keys(s:registry)
    let winnum = bufwinnr(str2nr(bufnum))
    if winnum >= 0
      execute printf('keepjumps %dwincmd w', winnum)
      call gita#util#observer#update()
    else
      call setbufvar(str2nr(bufnum), '_gita_observer_internal_update_required', 1)
    endif
  endfor
  execute printf('keepjumps %dwincmd w', winnum_saved)
endfunction

" Automatically start observation when it's sourced
augroup vim_gita_internal_observer
  autocmd! *
  autocmd BufWritePre  * call s:on_BufWritePre()
  autocmd BufWritePost * call s:on_BufWritePost()
  autocmd User GitaStatusModified nested call gita#util#observer#update_all()
augroup END
