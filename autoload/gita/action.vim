function! s:call_from_mapping(name) abort range
  try
    let candidates = gita#action#get_candidates(a:firstline, a:lastline)
    call gita#action#call(a:name, candidates)
  catch /^\%(vital: Git[:.]\|gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

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
        \ 'funcref': a:funcref,
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
  let name = has_key(action_book.aliases, a:name)
        \ ? action_book.aliases[a:name]
        \ : a:name
  if !has_key(action_book.actions, name)
    call gita#throw(printf(
          \ 'An action "%s" is not defined on a buffer "%s"',
          \ a:name, bufname('%'),
          \))
  endif
  return action_book.actions[name]
endfunction

function! gita#action#get_candidates(...) abort
  let action_book = gita#action#get_book()
  let sl = get(a:000, 0, line('.'))
  let el = get(a:000, 1, a:0 == 0 ? line('v') : sl)
  let [sline, eline] = sl < el ? [sl, el] : [el, sl]
  let candidates = filter(
        \ copy(action_book.funcref(sline, eline)),
        \ '!empty(v:val)'
        \)
  return candidates
endfunction

function! gita#action#filter(candidates, records, attrname) abort
  let candidates = filter(
        \ copy(a:candidates),
        \ 'index(a:records, v:val[a:attrname]) >= 0'
        \)
  return candidates
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
        \ ? printf('<Plug>(gita-%s)', substitute(a:name, ':', '-', 'g'))
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
          \ '%snoremap <buffer><silent> %s :%scall <SID>call_from_mapping("%s")<CR>',
          \ mode, mapping, mode ==# '[ni]' ? '<C-u>' : '', a:name,
          \)
  endfor
endfunction

function! gita#action#call(name, candidates) abort
  call gita#util#doautocmd('User', 'GitaActionCalledPre:' . a:name)
  let action = gita#action#get_action(a:name)
  let candidates = filter(
        \ copy(a:candidates),
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
  call gita#util#doautocmd('User', 'GitaActionCalledPost:' . a:name)
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
  catch /^\%(vital: Git[:.]\|gita:\)/
    call gita#util#handle_exception()
    return a:lhs
  endtry
endfunction
