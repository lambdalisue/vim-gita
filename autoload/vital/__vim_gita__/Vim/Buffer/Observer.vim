let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:_vital_created(module) abort
  let s:registry = {}
  let s:reserved = {}
endfunction

function! s:_on_BufWinEnter() abort
  let bufnum = string(bufnr('%'))
  if has_key(s:reserved, bufnum)
    unlet s:reserved[bufnum]
    silent! call s:update()
  endif
endfunction

function! s:attach(...) abort
  let s:registry[bufnr('%')] = get(a:000, 0, 'edit')
  augroup vital_vim_buffer_observer_attach
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested call s:_on_BufWinEnter()
  augroup END
endfunction

function! s:is_attached() abort
  let bufnum = string(bufnr('%'))
  return has_key(s:registry, bufnum)
        \ && exists('#vital_vim_buffer_observer_attach')
endfunction

function! s:update() abort
  let bufnum = string(bufnr('%'))
  if s:is_attached()
    if &verbose > 0
      echomsg printf('vital: Vim.Buffer.Observer: "%s" is performed on "%s"',
            \ s:registry[bufnum],
            \ bufname('%'),
            \)
    endif
    execute s:registry[bufnum]
  endif
endfunction

function! s:update_all() abort
  let winnum_saved = winnr()
  for bufnum in keys(s:registry)
    let winnum = bufwinnr(str2nr(bufnum))
    if winnum > 0 && getbufvar(str2nr(bufnum), '&autoread')
      execute printf('noautocmd keepjumps %dwincmd w', winnum)
      silent! call s:update()
    elseif bufexists(str2nr(bufnum))
      let s:reserved[bufnum] = 1
    else
      unlet s:registry[bufnum]
    endif
  endfor
  execute printf('noautocmd keepjumps %dwincmd w', winnum_saved)
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
