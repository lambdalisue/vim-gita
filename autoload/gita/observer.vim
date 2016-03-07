let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
if !exists('s:registry')
  let s:registry = {}
endif

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

function! gita#observer#attach(...) abort
  let Command = get(a:000, 0, 'edit')
  let s:registry[bufnr('%')] = Command
  augroup vim_gita_internal_observer_individual
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested
          \ if exists('b:_gita_observer_modified') |
          \   silent unlet b:_gita_observer_modified |
          \   call gita#observer#update() |
          \ endif
  augroup END
endfunction

function! gita#observer#detach() abort
  let bufnum  = bufnr('%')
  if has_key(s:registry, bufnum)
    unlet s:registry[bufnum]
  endif
endfunction

function! gita#observer#update() abort
  let bufnum = bufnr('%')
  if has_key(s:registry, bufnum)
    execute s:registry[bufnum]
  endif
endfunction

function! gita#observer#update_all() abort
  echomsg string(s:registry)
  let winnum_saved = winnr()
  for bufnum in keys(s:registry)
    let winnum = bufwinnr(str2nr(bufnum))
    if winnum >= 0
      execute printf('keepjumps %dwincmd w', winnum)
      call gita#observer#update()
    else
      call setbufvar(str2nr(bufnum), '_gita_observer_modified', 1)
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
