"******************************************************************************
" Git config parser (parser for 'git config --local -l')
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:parameter_pattern = '\v^([^\=]+)\=(.*)$'

function! s:_make_nested_dict(keys, value) abort
  if len(a:keys) == 1
    return {a:keys[0]: a:value}
  else
    return {a:keys[0]: s:_make_nested_dict(a:keys[1:], a:value)}
  endif
endfunction

function! s:_extend_nested_dict(expr1, expr2) abort
  let expr1 = deepcopy(a:expr1)
  for [key, value] in items(a:expr2)
    if has_key(expr1, key)
      if type(value) == 4 && type(expr1[key]) == 4
        let expr1[key] = s:_extend_nested_dict(expr1[key], value)
      else
        let expr1[key] = value
      endif
    else
      let expr1[key] = value
    endif
  endfor
  return expr1
endfunction

function! s:parse_record(line) abort
  let m = matchlist(a:line, s:parameter_pattern)
  if len(m) < 3
    throw 'vital: VCS.Git.ConfigParser: Parsing a record failed: ' . a:line
  endif
  " create a nested object
  let keys = split(m[1], '\.')
  let value = m[2]
  return s:_make_nested_dict(keys, value)
endfunction

function! s:parse(config) abort
  let obj = {}
  for line in split(a:config, '\v%(\r?\n)+')
    let obj = s:_extend_nested_dict(obj, s:parse_record(line))
  endfor
  return obj
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttabb et ai textwidth=0 fdm=marker
