function! s:get_action_function(name) abort
  return function(printf('gita#action#%s#action', a:name))
endfunction
function! s:get_define_plugin_mappings_function(name) abort
  return function(printf('gita#action#%s#define_plugin_mappings', a:name))
endfunction
function! s:get_define_default_mappings_function(name) abort
  return function(printf('gita#action#%s#define_default_mappings', a:name))
endfunction
function! s:get_get_mapping_table_function(name) abort
  return function(printf('gita#action#%s#get_mapping_table', a:name))
endfunction

function! s:parse_mapping(raw, rhs) abort
  " Note:
  " :help map-listing
  let pattern = printf(
        \ '\(...\)\s*\(\S\+\)\s*\([*&@]\{,3}\)\s*.*\(%s[^''" ]\+\)',
        \ a:rhs,
        \)
  let m = matchlist(a:raw, pattern)
  return m[1 : 4]
endfunction
function! s:filter_mappings(rhs, ...) abort
  let options = extend({
        \ 'noremap': 0,
        \ 'buffer': 0,
        \}, get(a:000, 0, {})
        \)
  let flag = join([
        \ options.noremap ? '*' : '',
        \ options.buffer ? '@' : '',
        \], '')
  let rhs = flag . '.*\zs' . a:rhs . '\ze\S*$'
  try
    redir => content
    silent execute 'map'
  finally
    redir END
  endtry
  return map(filter(
        \ split(content, "\r\\?\n"),
        \ 'v:val =~# rhs'
        \), 's:parse_mapping(v:val, a:rhs)'
        \)
endfunction
function! s:compare(i1, i2) abort
  return a:i1[1] == a:i2[1] ? 0 : a:i1[1] > a:i2[1] ? 1 : -1
endfunction
function! s:build_mapping_help(table) abort
  let mappings = s:filter_mappings('<Plug>(gita-', {
        \ 'noremap': 0,
        \ 'buffer': 1,
        \})
  let longest = 0
  let precursors = []
  for [mode, lhs, flag, rhs] in mappings
    if len(lhs) > longest
      let longest = len(lhs)
    endi
    call add(precursors, [lhs, get(a:table, rhs, rhs)])
  endfor
  let contents = []
  for [lhs, rhs] in sort(precursors, 's:compare')
    call add(contents, printf(
          \ printf('%%-%ds : %%s', longest),
          \ lhs, rhs
          \))
  endfor
  return contents
endfunction

function! gita#action#do(name, candidates, ...) abort
  let action = gita#action#get()
  let args = [a:candidates] + a:000
  if has_key(action.actions, a:name)
    call call(action.actions[a:name], args, action.actions)
  else
    call call(s:get_action_function(a:name), args)
  endif
endfunction

function! gita#action#call(name, ...) abort range
  let action = gita#action#get()
  try
    let candidates = map(
          \ range(a:firstline, a:lastline),
          \ 'action.get_entry(v:val - 1)'
          \)
    call filter(candidates, '!empty(v:val)')
    call call('gita#action#do', [a:name, candidates] + a:000)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#action#define(fn) abort
  let action = {
        \ 'get_entry': a:fn,
        \ 'actions': {},
        \ 'mapping_table': {},
        \}
  let b:_gita_action = action
  return action
endfunction

function! gita#action#get() abort
  if !exists('b:_gita_action')
    call gita#throw(printf(
          \ '"b:_gita_action on %s is not defined.', bufname('%')
          \))
  endif
  return b:_gita_action
endfunction

function! gita#action#get_mapping_help() abort
  let action = gita#action#get()
  return s:build_mapping_help(action.mapping_table)
endfunction

function! gita#action#include(enable_default_mappings, name) abort
  let action = gita#action#get()
  call call(s:get_define_plugin_mappings_function(a:name), [])
  if a:enable_default_mappings
    call call(s:get_define_default_mappings_function(a:name), [])
  endif
  call extend(
        \ action.mapping_table,
        \ call(s:get_get_mapping_table_function(a:name), [])
        \)
endfunction

function! gita#action#includes(enable_default_mappings, names) abort
  for name in a:names
    call gita#action#include(a:enable_default_mappings, name)
  endfor
endfunction

function! gita#action#smart_map(lhs, rhs) abort range
  let action = gita#action#get()
  try
    let candidates = map(
          \ range(a:firstline, a:lastline),
          \ 'action.get_entry(v:val - 1)'
          \)
    let candidates = filter(candidates, '!empty(v:val)')
    return empty(candidates) ? a:lhs : a:rhs
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
