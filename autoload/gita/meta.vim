let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:get_meta(expr) abort " {{{
  let meta = gita#compat#getwinvar(bufwinnr(a:expr), '_gita_meta', {})
  let meta = empty(meta)
        \ ? gita#compat#getbufvar(a:expr, '_gita_meta', {})
        \ : meta
  if !empty(getwinvar(bufwinnr(a:expr), '_gita_meta'))
    call setwinvar(bufwinnr(a:expr), '_gita_meta', meta)
  else
    call setbufvar(a:expr, '_gita_meta', meta)
  endif
  return meta
endfunction " }}}

function! gita#meta#get(name, ...) abort " {{{
  let expr = get(a:000, 1, '%')
  let meta = s:get_meta(expr)
  return get(meta, a:name, get(a:000, 0, ''))
endfunction " }}}
function! gita#meta#set(name, value, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta(expr)
  let meta[a:name] = a:value
endfunction " }}}
function! gita#meta#extend(meta, ...) abort " {{{
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta(expr)
  call extend(meta, a:meta)
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
