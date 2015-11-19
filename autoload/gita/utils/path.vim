let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:P = gita#import('System.Filepath')
let s:T_LIST = type([])
let s:IS_WIN = has('win16') || has('win32') || has('win64')

function! s:ensure_abspath(path) abort " {{{
  if s:P.is_absolute(a:path)
    return a:path
  endif
  " Note:
  "   the behavior of ':p' for non existing file path is not defined
  return filereadable(a:path)
        \ ? fnamemodify(a:path, ':p')
        \ : s:P.join(fnamemodify(getcwd(), ':p'), a:path)
endfunction " }}}
function! s:ensure_relpath(path) abort " {{{
  if s:P.is_relative(a:path)
    return a:path
  endif
  return fnamemodify(deepcopy(a:path), ':~:.')
endfunction " }}}
" function! s:ensure_unixpath(path) abort " {{{
if s:IS_WIN
  function! s:ensure_unixpath(path) abort
    return fnamemodify(a:path, ':gs?\\?/?')
  endfunction
else
  function! s:ensure_unixpath(path) abort
    return a:path
  endfunction
endif " }}}
" function! s:ensure_realpath(path) abort " {{{
if s:IS_WIN
  function! s:ensure_realpath(path) abort
    if exists('&shellslash') && &shellslash
      return a:path
    else
      return fnamemodify(a:path, ':gs?/?\\?')
    endif
  endfunction
else
  function! s:ensure_realpath(path) abort
    return a:path
  endfunction
endif " }}}

function! gita#utils#path#expand(expr) abort " {{{
  if a:expr =~# '^%'
    let expr = '%'
    let modi = substitute(a:expr, '^%', '', '')
    let filename = gita#meta#get('filename', '', expr)
    return empty(filename)
          \ ? expand(a:expr)
          \ : fnamemodify(filename, modi)
  else
    return expand(a:expr)
  endif
endfunction " }}}
function! gita#utils#path#unix_abspath(path) abort " {{{
  if type(a:path) == s:T_LIST
    return map(a:path, 'gita#utils#path#unix_abspath(v:val)')
  else
    return s:ensure_unixpath(s:ensure_abspath(gita#utils#path#expand(a:path)))
  endif
endfunction " }}}
function! gita#utils#path#unix_relpath(path) abort " {{{
  if type(a:path) == s:T_LIST
    return map(a:path, 'gita#utils#path#unix_relpath(v:val)')
  else
    return s:ensure_unixpath(s:ensure_relpath(gita#utils#path#expand(a:path)))
  endif
endfunction " }}}
function! gita#utils#path#real_abspath(path) abort " {{{
  if type(a:path) == s:T_LIST
    return map(a:path, 'gita#utils#path#real_abspath(v:val)')
  else
    return s:ensure_realpath(s:ensure_abspath(gita#utils#path#expand(a:path)))
  endif
endfunction " }}}
function! gita#utils#path#real_relpath(path) abort " {{{
  if type(a:path) == s:T_LIST
    return map(a:path, 'gita#utils#path#real_relpath(v:val)')
  else
    return s:ensure_realpath(s:ensure_relpath(gita#utils#path#expand(a:path)))
  endif
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
