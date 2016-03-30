function! gita#action#is_attached() abort
  return exists('b:_gita_action_book')
endfunction

function! gita#action#is_satisfied(candidate, requirements) abort
  for requirement in a:requirements
    if !has_key(a:candidate, requirement)
      return 0
    endif
  endfor
  return 1
endfunction

function! gita#action#attach(funcref) abort
  let b:_gita_action_book = {
        \ 'get_candidate': a:funcref,
        \ 'actions': {},
        \ 'aliases': {},
        \}
  return b:_gita_action_book
endfunction

function! gita#action#get_book() abort
  if !exists('b:_gita_action_book')
    call gita#throw(printf(
          \ 'No action has attached on a buffer "%s"',
          \ bufname('%')
          \))
  endif
  return b:_gita_action_book
endfunction

function! gita#action#get_action(name) abort
  let action_book = gita#action#get_book()
  if !has_key(action_book.actions, a:name)
    call gita#throw(printf(
          \ 'An action "%s" is not defined on a buffer "%s"',
          \ a:name, bufname('%'),
          \))
  endif
  return action_book.actions[a:name]
endfunction

function! gita#action#get_candidates(...) abort
  let action_book = gita#action#get_book()
  let start_line = get(a:000, 0, line('.'))
  let end_line = get(a:000, 1, start_line)
  let candidates = map(
        \ range(start_line, end_line),
        \ 'action_book.get_candidate(v:val - 1)'
        \)
  call filter(candidates, '!empty(v:val)')
  return candidates
endfunction

function! gita#action#find_candidate(candidates, record, attrname) abort
  for candidate in a:candidates
    if candidate[a:attrname] ==# a:record
      return candidate
    endif
  endfor
  return {}
endfunction

function! gita#action#call(name, ...) abort range
  let action = gita#action#get_action(a:name)
  let candidates = a:0 == 0
        \ ? gita#action#get_candidates(a:firstline, a:lastline)
        \ : a:1
  let candidates = filter(
        \ copy(candidates),
        \ 'gita#action#is_satisfied(v:val, action.requirements)',
        \)
  if !empty(action.requirements) && empty(candidates)
    return
  endif
  if action.mapping_mode =~# '[vx]'
    call call(action.fn, [candidates, action.options])
  else
    call call(action.fn, [get(candidates, 0, {}), action.options])
  endif
endfunction

function! gita#action#define(name, fn, ...) abort
  let options = extend({
        \ 'alias': a:name,
        \ 'description': '',
        \ 'mapping': '',
        \ 'mapping_mode': 'nv',
        \ 'requirements': [],
        \ 'options': {},
        \}, get(a:000, 0, {}))
  let description = empty(options.description)
        \ ? printf('Perform %s action', options.alias)
        \ : options.description
  let mapping = empty(options.mapping)
        \ ? printf('<Plug>(gita-%s)', substitute(options.alias, ':', '-', 'g'))
        \ : options.mapping
  let action_book = gita#action#get_book()
  let action_book.aliases[options.alias] = a:name
  let action_book.actions[a:name] = {
        \ 'fn': a:fn,
        \ 'alias': options.alias,
        \ 'description': description,
        \ 'mapping': mapping,
        \ 'mapping_mode': options.mapping_mode,
        \ 'requirements': options.requirements,
        \ 'options': options.options,
        \}
  for mode in split(options.mapping_mode, '\zs')
    execute printf(
          \ '%snoremap <buffer><silent> %s :%scall gita#action#call("%s")<CR>',
          \ mode, mapping, mode ==# '[ni]' ? '<C-u>' : '', a:name,
          \)
  endfor
endfunction

function! gita#action#include(names, ...) abort
  let disable_mapping = get(a:000, 0)
  for name in a:names
    let domain = matchstr(name, '^[^:]\+')
    call call(printf('gita#action#%s#define', domain), [disable_mapping])
  endfor
endfunction

function! gita#action#smart_map(lhs, rhs) abort range
  try
    let candidates = gita#action#get_candidates(a:firstline, a:lastline)
    return empty(candidates) ? a:lhs : a:rhs
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
    return a:lhs
  endtry
endfunction
