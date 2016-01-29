function! s:get_action_function(name) abort
  return function(printf('hita#action#%s#action', a:name))
endfunction
function! s:get_define_plugin_mappings_function(name) abort
  return function(printf('hita#action#%s#define_plugin_mappings', a:name))
endfunction
function! s:get_define_default_mappings_function(name) abort
  return function(printf('hita#action#%s#define_default_mappings', a:name))
endfunction
function! s:get_get_mapping_table_function(name) abort
  return function(printf('hita#action#%s#get_mapping_table', a:name))
endfunction

function! s:parse_mapping(raw) abort
  " Note:
  " :help map-listing
  let m = matchlist(a:raw, '\(...\)\s*\(\S\+\)\s*\([*&@]\{,3}\)\s*\(\S\+\)')
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
  let rhs = flag . a:rhs . '\S*$'
  try
    redir => content
    silent execute 'map'
  finally
    redir END
  endtry
  return map(filter(
        \ split(content, "\r\\?\n"),
        \ 'v:val =~# rhs'
        \), 's:parse_mapping(v:val)'
        \)
endfunction
function! s:compare(i1, i2) abort
  return a:i1[1] == a:i2[1] ? 0 : a:i1[1] > a:i2[1] ? 1 : -1
endfunction
" @vimlint(EVL102, 1, l:mode)
" @vimlint(EVL102, 1, l:flag)
function! s:build_mapping_help(table) abort
  let mappings = s:filter_mappings('<Plug>(hita-', {
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
" @vimlint(EVL102, 0, l:mode)
" @vimlint(EVL102, 0, l:flag)

function! hita#action#do(name, candidates, ...) abort range
  let action = hita#action#get()
  let args = [a:candidates] + a:000
  if has_key(action.actions, a:name)
    call call(action.actions[a:name], args, action.actions)
  else
    call call(s:get_action_function(a:name), args)
  endif
endfunction

function! hita#action#call(name, ...) abort range
  let action = hita#action#get()
  let candidates = map(
        \ copy(range(a:firstline, a:lastline)),
        \ 'action.get_entry(v:val - 1)'
        \)
  call filter(candidates, '!empty(v:val)')
  call call('hita#action#do', [a:name, candidates] + a:000)
endfunction

function! hita#action#define(fn) abort
  let action = {
        \ 'get_entry': a:fn,
        \ 'actions': {},
        \ 'mapping_table': {},
        \}
  let b:_hita_action = action
  return action
endfunction

function! hita#action#get() abort
  if !exists('b:_hita_action')
    call hita#throw(printf(
          \ '"b:_hita_action on %s is not defined.', bufname('%')
          \))
  endif
  return b:_hita_action
endfunction

function! hita#action#get_mapping_help() abort
  let action = hita#action#get()
  return s:build_mapping_help(action.mapping_table)
endfunction

function! hita#action#include(enable_default_mappings, name) abort
  let action = hita#action#get()
  call call(s:get_define_plugin_mappings_function(a:name), [])
  if a:enable_default_mappings
    call call(s:get_define_default_mappings_function(a:name), [])
  endif
  call extend(
        \ action.mapping_table,
        \ call(s:get_get_mapping_table_function(a:name), [])
        \)
endfunction

function! hita#action#includes(enable_default_mappings, names) abort
  for name in a:names
    call hita#action#include(a:enable_default_mappings, name)
  endfor
endfunction
