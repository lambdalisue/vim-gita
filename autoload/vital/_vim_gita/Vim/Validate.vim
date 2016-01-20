let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \]
endfunction
function! s:_translate(text, table) abort
  let text = a:text
  for [key, value] in items(a:table)
    let text = substitute(
          \ text, key,
          \ s:Prelude.is_string(value) ? value : string(value),
          \ 'g')
    unlet value
  endfor
  return text
endfunction

function! s:throw(msg) abort
  throw printf('vital: Vim.Validate: ValidationError: %s', a:msg)
endfunction

function! s:true(value, ...) abort
  let msg = get(a:000, 0, 'A value "%value" requires to be True value')
  if !a:value
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction
function! s:false(value, ...) abort
  let msg = get(a:000, 0, 'A value "%value" requires to be False value')
  if a:value
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction

function! s:exists(value, list, ...) abort
  let msg = get(a:000, 0, 'A value "%value" reqiured to exist in %list')
  if index(a:list, a:value) == -1
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%list': a:list,
          \}))
  endif
endfunction
function! s:not_exists(value, list, ...) abort
  let msg = get(a:000, 0, 'A value "%value" reqiured to NOT exist in %list')
  if index(a:list, a:value) >= 0
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%list': a:list,
          \}))
  endif
endfunction

function! s:key_exists(value, dict, ...) abort
  let msg = get(a:000, 0, 'A key "%value" reqiured to exist in %dict')
  if !has_key(a:dict, a:value)
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%dict': a:dict,
          \}))
  endif
endfunction
function! s:key_not_exists(value, dict, ...) abort
  let msg = get(a:000, 0, 'A key "%value" reqiured to NOT exist in %dict')
  if has_key(a:dict, a:value)
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%dict': a:dict,
          \}))
  endif
endfunction

function! s:empty(value, ...) abort
  let msg = get(a:000, 0, 'Non empty value "%value" is not allowed')
  if !empty(a:value)
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \}))
  endif
endfunction
function! s:not_empty(value, ...) abort
  let msg = get(a:000, 0, 'An empty value is not allowed')
  if empty(a:value)
    call s:throw(s:_translate(msg, {}))
  endif
endfunction

function! s:pattern(value, pattern, ...) abort
  let msg = get(a:000, 0, '%value does not follow a valid pattern %pattern')
  if a:value !~# a:pattern
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%pattern': a:pattern,
          \}))
  endif
endfunction
function! s:not_pattern(value, pattern, ...) abort
  let msg = get(a:000, 0, '%value follow an invalid pattern %pattern')
  if a:value =~# a:pattern
    call s:throw(s:_translate(msg, {
          \ '%value': a:value,
          \ '%pattern': a:pattern,
          \}))
  endif
endfunction

function! s:call_silently(fn, ...) abort
  let args = get(a:000, 0, [])
  let dict = get(a:000, 1, {})
  let default = get(a:000, 2, '')
  try
    if empty(dict)
      return call(a:fn, args)
    else
      return call(a:fn, args, dict)
    endif
  catch /^vital: Vim.Validate: ValidationError:/
    return default
  endtry
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
