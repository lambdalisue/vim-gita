let s:V = vital#of('vim_gita')
let s:Prelude = s:V.import('Prelude')
let s:Compat = s:V.import('Vim.Compat')
let s:Path = s:V.import('System.Filepath')
let s:NAME = '_gita_meta'

function! s:get_meta_instance(bufnum) abort
  let meta = s:Compat.getbufvar(a:bufnum, s:NAME, {})
  if bufexists(a:bufnum)
    call setbufvar(a:bufnum, s:NAME, meta)
  endif
  return meta
endfunction

function! gita#meta#get(name, ...) abort
  let default = get(a:000, 0, '')
  let expr    = get(a:000, 1, '%')
  let meta    = s:get_meta_instance(bufnr(expr))
  return get(meta, a:name, default)
endfunction

function! gita#meta#get_for(content_type, name, ...) abort
  let default = get(a:000, 0, '')
  let expr    = get(a:000, 1, '%')
  if gita#meta#get('content_type', '', expr) !~# a:content_type
    return default
  endif
  return call('gita#meta#get', [a:name, default, expr])
endfunction

function! gita#meta#set(name, value, ...) abort
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta_instance(bufnr(expr))
  let meta[a:name] = a:value
endfunction

function! gita#meta#remove(name, ...) abort
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta_instance(bufnr(expr))
  if has_key(meta, a:name)
    unlet meta[a:name]
  endif
endfunction

function! gita#meta#clear(...) abort
  let expr = get(a:000, 0, '%')
  call setbufvar(expr, s:NAME, {})
endfunction

function! gita#meta#expand(expr) abort
  if empty(a:expr)
    return ''
  endif
  let meta_filename = gita#meta#get('filename', '', a:expr)
  let real_filename = expand(
        \ s:Prelude.is_string(a:expr) ? a:expr : bufname(a:expr)
        \)
  let filename = empty(meta_filename) ? real_filename : meta_filename
  " NOTE: Always return a real absolute path
  return s:Path.abspath(s:Path.realpath(filename))
endfunction
