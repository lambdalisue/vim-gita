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
  let bufnum  = get(a:000, 0, bufnr('%'))
  let Command = get(a:000, 1, 'edit')
  let s:registry[bufnum] = Command
endfunction

function! gita#observer#detach(...) abort
  let bufnum  = get(a:000, 0, bufnr('%'))
  if has_key(s:registry, bufnum)
    unlet s:registry[bufnum]
  endif
endfunction

function! gita#observer#update_all() abort
  let winnum_saved = winnr()
  for [bufnum, Command] in items(s:registry)
    let winnum = bufwinnr(bufname(bufnum))
    if winnum >= 0
      execute printf('keepjumps %dwincmd w', winnum)
      if s:Prelude.is_funcref(Command)
        call call(Command, [])
      else
        execute Command
      endif
    endif
    unlet Command
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
