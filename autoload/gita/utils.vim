let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#import('System.Filepath')
let s:is_windows = has('win16') || has('win32') || has('win64')

function! s:smart_string(value) abort " {{{
  let vtype = type(a:value)
  if vtype == type('')
    return a:value
  elseif vtype == type(0)
    return a:value ? string(a:value) : ''
  elseif vtype == type([]) || vtype == type({})
    return !empty(a:value) ? string(a:value) : ''
  else
    return string(a:value)
  endif
endfunction " }}}
function! gita#utils#format_string(format, format_map, data) abort " {{{
  " format rule:
  "   %{<left>|<right>}<key>
  "     '<left><value><right>' if <value> != ''
  "     ''                     if <value> == ''
  "   %{<left>}<key>
  "     '<left><value>'        if <value> != ''
  "     ''                     if <value> == ''
  "   %{|<right>}<key>
  "     '<value><right>'       if <value> != ''
  "     ''                     if <value> == ''
  if empty(a:data)
    return ''
  endif
  let pattern_base = '\v\%%%%(\{([^\}\|]*)%%(\|([^\}\|]*)|)\}|)%s'
  let str = copy(a:format)
  for [key, value] in items(a:format_map)
    let result = s:smart_string(get(a:data, value, ''))
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', escape(result, '\')) : ''
    let str = substitute(str, '\C' . pattern, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction " }}}
function! gita#utils#eget(obj, name, default) abort " {{{
  let result = get(a:obj, a:name, a:default)
  return empty(result) ? a:default : result
endfunction " }}}
function! gita#utils#clip(content) abort " {{{
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction " }}}

function! gita#utils#expand(expr) abort " {{{
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
function! gita#utils#ensure_abspath(path) abort " {{{
  if s:P.is_absolute(a:path)
    return a:path
  endif
  " Note:
  "   the behavior of ':p' for non existing file path is not defined
  return filereadable(a:path)
        \ ? fnamemodify(a:path, ':p')
        \ : s:P.join(fnamemodify(getcwd(), ':p'), a:path)
endfunction " }}}
function! gita#utils#ensure_relpath(path) abort " {{{
  if s:P.is_relative(a:path)
    return a:path
  endif
  return fnamemodify(deepcopy(a:path), ':~:.')
endfunction " }}}
function! gita#utils#ensure_pathlist(pathlist) abort " {{{
  return map(deepcopy(a:pathlist),
        \ 'gita#utils#ensure_abspath(gita#utils#expand(v:val))',
        \)
endfunction " }}}

" function! gita#utils#ensure_unixpath(path)/ensure_realpath(path) abort " {{{
if s:is_windows && exists('&shellslash')
  function! gita#utils#ensure_unixpath(path) abort " {{{
    return fnamemodify(a:path, ':gs?\\?/?')
  endfunction " }}}
  function! gita#utils#ensure_realpath(path) abort " {{{
    if &shellslash
      return a:path
    else
      return fnamemodify(a:path, ':gs?/?\\?')
    endif
  endfunction " }}}
  function! gita#utils#ensure_unixpathlist(pathlist) abort " {{{
    return map(deepcopy(a:pathlist),
          \ 'gita#utils#ensure_unixpath(gita#utils#ensure_abspath(gita#utils#expand(v:val)))',
          \)
  endfunction " }}}
  function! gita#utils#ensure_realpathlist(pathlist) abort " {{{
    return map(deepcopy(a:pathlist),
          \ 'gita#utils#ensure_realpath(gita#utils#ensure_abspath(gita#utils#expand(v:val)))',
          \)
  endfunction " }}}
else
  function! gita#utils#ensure_unixpath(path) abort " {{{
    return a:path
  endfunction " }}}
  function! gita#utils#ensure_realpath(path) abort " {{{
    return a:path
  endfunction " }}}
  function! gita#utils#ensure_unixpathlist(pathlist) abort " {{{
    return gita#utils#ensure_pathlist(a:pathlist)
  endfunction " }}}
  function! gita#utils#ensure_realpathlist(pathlist) abort " {{{
    return gita#utils#ensure_pathlist(a:pathlist)
  endfunction " }}}
endif
" }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
