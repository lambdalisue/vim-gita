let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Compat = s:V.import('Vim.Compat')

function! s:get_meta(expr) abort
  let bufnum = bufnr(a:expr)
  let meta = s:Compat.getbufvar(bufnum, '_hita_meta', {})
  call setbufvar(bufnum, '_hita_meta', meta)
  return meta
endfunction

function! hita#meta#get(name, ...) abort
  let expr = get(a:000, 1, '%')
  let meta = s:get_meta(expr)
  return get(meta, a:name, get(a:000, 0, ''))
endfunction
function! hita#meta#set(name, value, ...) abort
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta(expr)
  let meta[a:name] = a:value
endfunction
function! hita#meta#extend(meta, ...) abort
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta(expr)
  call extend(meta, a:meta)
endfunction

function! hita#meta#get_filename(...) abort
  return call(
        \ function('hita#meta#get'),
        \ extend(['filename'], a:000)
        \)
endfunction
function! hita#meta#set_filename(filename, ...) abort
  return call(
        \ function('hita#meta#set'),
        \ extend(['filename', a:filename], a:000)
        \)
endfunction
function! hita#meta#get_commit(...) abort
  return call(
        \ function('hita#meta#get'),
        \ extend(['commit'], a:000)
        \)
endfunction
function! hita#meta#set_commit(commit, ...) abort
  return call(
        \ function('hita#meta#set'),
        \ extend(['commit', a:commit], a:000)
        \)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
