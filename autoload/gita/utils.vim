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

let s:P = gita#utils#import('Prelude')
let s:S = gita#utils#import('VCS.Git.StatusParser')

" string
function! gita#utils#smart_string(value) abort " {{{
  let P = gita#utils#import('Prelude')
  if P.is_string(a:value)
    return a:value
  elseif P.is_numeric(a:value)
    return a:value ? string(a:value) : ''
  elseif P.is_list(a:value) || P.is_dict(a:value)
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
    let result = gita#utils#smart_string(get(a:data, value, ''))
    let pattern = printf(pattern_base, key)
    let repl = strlen(result) ? printf('\1%s\2', result) : ''
    let str = substitute(str, pattern, repl, 'g')
  endfor
  return substitute(str, '\v^\s+|\s+$', '', 'g')
endfunction " }}}

" ensure
function! gita#utils#ensure_string(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_string(a:x) ? a:x : [a:x]
endfunction " }}}
function! gita#utils#ensure_list(x) abort " {{{
  let P = gita#utils#import('Prelude')
  return P.is_list(a:x) ? a:x : [a:x]
endfunction " }}}

" misc
function! gita#utils#get_status(path) abort " {{{
  let gita = gita#get()
  let options = {
        \ 'porcelain': 1,
        \ 'ignore_submodules': 1,
        \ '--': [a:path],
        \}
  let result = gita.operations.status(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return {}
  endif
  let statuses = s:S.parse(result.stdout)
  return get(statuses.all, 0, {})
endfunction " }}}
function! gita#utils#doautocmd(name) abort " {{{
  let name = printf('vim-gita-%s', a:name)
  if 703 < v:version || (v:version == 703 && has('patch438'))
    silent execute 'doautocmd <nomodeline> User ' . name
  else
    silent execute 'doautocmd User ' . name
  endif
endfunction " }}}
function! gita#utils#expand(expr) abort " {{{
  if a:expr =~# '^%'
    let expr = '%'
    let modi = substitute(a:expr, '^%', '', '')
    let original_filename = gita#get_original_filename(expr)
    return empty(original_filename)
          \ ? expand(a:expr)
          \ : fnamemodify(original_filename, modi)
  else
    return expand(a:expr)
  endif
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
