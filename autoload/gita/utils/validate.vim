let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:P = gita#import('System.Filepath')


function s:throw(...) abort " {{{
  let bits = filter(deepcopy(a:000), '!empty(v:val)')
  throw printf('vim-gita: ValidationError: %s', join(
        \ map(bits, 'type(v:val) == type("") ? v:val : string(v:val)'),
        \))
endfunction " }}}

function! gita#utils#validate#require(dict, key, ...) abort " {{{
  let name = get(a:000, 0, 'dictionary')
  if !has_key(a:dict, a:key)
    call s:throw(printf('no "%s" is found in the %s', a:key, name))
  endif
endfunction " }}}
function! gita#utils#validate#empty(value, ...) abort " {{{
  let name = get(a:000, 0, 'value')
  if empty(a:value)
    call s:throw(printf('empty "%s" is not permitted', name))
  endif
endfunction " }}}
function! gita#utils#validate#abspath(path, ...) abort " {{{
  let name = get(a:000, 0, 'path')
  if !s:P.is_absolute(a:path)
    call s:throw(printf('"%s" is not absolute path', name))
  endif
endfunction " }}}
function! gita#utils#validate#relpath(path, ...) abort " {{{
  let name = get(a:000, 0, 'path')
  if !s:P.is_relative(a:path)
    call s:throw(printf('"%s" is not relative path', name))
  endif
endfunction " }}}
function! gita#utils#validate#pattern(value, pattern, ...) abort " {{{
  let name = get(a:000, 0, 'value')
  if a:value !~# a:pattern
    call s:throw(printf(
          \ '"%s" does not follow the pattern "%s"',
          \ name, a:pattern
          \))
  endif
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
