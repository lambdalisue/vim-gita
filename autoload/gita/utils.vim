let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vim_gita')
function! gita#utils#import(name) abort " {{{
  let cache_name = printf(
        \ '_vital_module_%s',
        \ substitute(a:name, '\.', '_', 'g'),
        \)
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:V.import(a:name)
  endif
  return s:[cache_name]
endfunction " }}}

let s:P = gita#utils#import('System.Filepath')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:TYPES = {
      \ 'STRING': type(''),
      \ 'NUMBER': type(0),
      \ 'LIST': type([]),
      \ 'DICT': type({}),
      \}

" string
function! s:smart_string(value) abort " {{{
  let type = type(a:value)
  if type == s:TYPES.STRING
    return a:value
  elseif type == s:TYPES.NUMBER
    return a:value ? string(a:value) : ''
  elseif type == s:TYPES.LIST || type == s:TYPES.DICT
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
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pattern, repl, 'gI')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
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

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
