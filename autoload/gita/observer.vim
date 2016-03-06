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

function! gita#observer#attach(bufnum, ...) abort
  let command = get(a:000, 0, 'edit')
  let s:registry[a:bufnum] = command
endfunction

function! gita#observer#detach(bufnum) abort
  if has_key(s:registry, a:bufnum)
    unlet s:registry[a:bufnum]
  endif
endfunction

function! gita#observer#update_all() abort
  let winnum_saved = winnr()
  for [bufnum, command] in items(s:registry)
    if bufexists(bufnum) && bufwinnr(bufnum)
      execute printf('keepjumps %d wincmd w', bufwinnr(bufnum))
      execute command
    endif
  endfor
  execute printf('keepjumps %dwincmd w', winnum_saved)
endfunction

function! gita#observer#start() abort
  augroup vim_gita_internal_observer
    autocmd! *
    autocmd BufWritePre  * call s:on_BufWritePre()
    autocmd BufWritePost * call s:on_BufWritePost()
    autocmd User GitaStatusModified nested call gita#observer#update_all()
  augroup END
endfunction

function! gita#observer#stop() abort
  augroup vim_gita_internal_observer
    autocmd! *
  augroup END
endfunction

" Automatically start observation when it's sourced
call gita#observer#start()
