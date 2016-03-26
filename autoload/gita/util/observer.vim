let s:registry = get(s:, 'registry', {})
let s:update_required_registry = {}

function! gita#util#observer#attach(...) abort
  let s:registry[bufnr('%')] = get(a:000, 0, 'silent doautocmd BufReadCmd')
  augroup vim_gita_internal_util_observer_attach
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested
          \ if get(s:update_required_registry, bufnr('%')) |
          \   unlet s:update_required_registry[bufnr('%')] |
          \   call gita#util#observer#update() |
          \ endif
  augroup END
  " NOTE:
  " When buffer is wipeouted and a new buffer is created, the buffer number
  " may equal so add a buffer variable to make sure the buffer is attached.
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
  for bufnum in keys(s:registry)
    let bufnr = str2nr(bufnum)
    let winnum = bufwinnr(bufnr)
    if winnum > 0
      execute printf('noautocmd keepjumps %dwincmd w', winnum)
      call gita#util#observer#update()
    elseif bufexists(bufnr)
      " reserve to 'update'
      let s:update_required_registry[bufnr] = 1
    else
      " the buffer is gone
      unlet s:registry[bufnr]
    endif
  endfor
  execute printf('noautocmd keepjumps %dwincmd w', winnum_saved)
endfunction

" Automatically start observation when it's sourced
augroup vim_gita_internal_util_observer
  autocmd! *
  autocmd User GitaStatusModified nested call gita#util#observer#update_all()
augroup END
