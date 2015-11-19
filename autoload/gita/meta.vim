let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:TYPE_NUM = type(0)

function! s:get_winmeta(expr) abort " {{{
  let winnum = bufwinnr(a:expr)
  let meta = gita#compat#getwinvar(winnum, '_gita_meta', 0)
  call gita#prompt#debug('s:get_winmeta', winnum, meta)
  if type(meta) == s:TYPE_NUM
    return {}
  else
    " store w:_gita_meta only when the variable exists
    call setwinvar(winnum, '_gita_meta', meta)
    return meta
  endif
endfunction " }}}
function! s:get_bufmeta(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  let meta = gita#compat#getbufvar(bufnum, '_gita_meta', {})
  call gita#prompt#debug('s:get_bufmeta', bufnum, meta)
  call setbufvar(bufnum, '_gita_meta', meta)
  return meta
endfunction " }}}
function! s:get_meta(expr) abort " {{{
  let winmeta = s:get_winmeta(a:expr)
  let bufmeta = s:get_bufmeta(a:expr)
  return empty(winmeta) ? bufmeta : winmeta
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

function! gita#meta#get_filename(...) abort " {{{
  return call(
        \ function('gita#meta#get'),
        \ extend(['filename'], a:000)
        \)
endfunction " }}}
function! gita#meta#set_filename(filename, ...) abort " {{{
  return call(
        \ function('gita#meta#set'),
        \ extend(['filename', a:filename], a:000)
        \)
endfunction " }}}
function! gita#meta#get_commit(...) abort " {{{
  return call(
        \ function('gita#meta#get'),
        \ extend(['commit'], a:000)
        \)
endfunction " }}}
function! gita#meta#set_commit(commit, ...) abort " {{{
  return call(
        \ function('gita#meta#set'),
        \ extend(['commit', a:commit], a:000)
        \)
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
