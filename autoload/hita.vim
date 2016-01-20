let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vim_gita')
let s:file = expand('<sfile>:p')
let s:repo = fnamemodify(s:file, ':h')

function! hita#vital() abort
  return s:V
endfunction

function! hita#throw(msg) abort
  throw printf('vim-hita: %s', a:msg)
endfunction
function! hita#expand(expr) abort
  return gita#meta#get('filename', expand(a:expr), a:expr)
endfunction

function! hita#define_variables(prefix, defaults) abort
  " Note:
  "   Funcref is not supported while the variable must start with a capital
  let prefix = empty(a:prefix)
        \ ? 'g:hita'
        \ : printf('g:hita#%s', a:prefix)
  for [key, value] in items(a:defaults)
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      silent execute printf('let %s = %s', name, string(value))
    endif
    unlet value
  endfor
endfunction


call hita#define_variables('', {
      \ 'test': 0,
      \ 'debug': 0,
      \ 'develop': 1,
      \})



let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
