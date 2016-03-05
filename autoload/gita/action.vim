let s:V = gita#vital()

function! gita#action#attach(fn) abort
  let action_holder = {
        \ 'get_candidates': a:fn,
        \ 'actions': {},
        \}
  let b:_gita_action_holder = action_holder

endfunction

function! gita#action#get_holder() abort
  if !exists('b:_gita_action_holder')
    call gita#throw(printf(
          \ 'No action has attached on a buffer %s', bufname('%')
          \))
  endif
  return b:_gita_action_holder
endfunction

function! gita#action#get_action(name) abort
  let action_holder = gita#action#get_holder()
  if !has_key(action_holder.actions, a:name)
    call gita#throw(printf(
          \ 'An action "%s" is not defined on a buffer %s', a:name, bufname('%'),
          \))
  endif
  return action_holder.actions[a:name]
endfunction

function! gita#action#get_candidates(...) abort
  let action_holder = gita#action#get_holder()
  let start_line = get(a:000, 0, line('.'))
  let end_line = get(a:000, 1, start_line)
  let candidates = map(
        \ range(start_line, end_line),
        \ 'action_holder.get_candidates(v:val - 1)'
        \)
  call filter(candidates, '!empty(v:val)')
  return candidates
endfunction

function! gita#action#do(name, candidates) abort
  let action = gita#action#get_action(a:name)
  call call(action.fn, [a:candidates, action.options])
endfunction

function! gita#action#call(name) abort range
  try
    let candidates = gita#action#get_candidates(a:firstline, a:lastline)
    call gita#action#do(a:name, candidates)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#action#define(name, fn, ...) abort
  let options = extend({
        \ 'description': printf('Perform %s action', a:name),
        \ 'mapping': printf('<Plug>(gita-%s)', substitute(a:name, ':', '-', 'g')),
        \ 'mapping_mode': 'nv',
        \ 'options': {},
        \}, get(a:000, 0, {}))
  let action_holder = gita#action#get_holder()
  let action_holder.actions[a:name] = {
        \ 'fn': a:fn,
        \ 'description': options.description,
        \ 'mapping': options.mapping,
        \ 'mapping_mode': options.mapping_mode,
        \ 'options': options.options,
        \}
  if !empty(options.mapping)
    for mode in split(options.mapping_mode, '\zs')
      execute printf(
            \ '%snoremap <buffer><silent> %s :%scall gita#action#call("%s")<CR>',
            \ mode, options.mapping, mode ==# '[ni]' ? '<C-u>' : '', a:name,
            \)
    endfor
  endif
endfunction

function! gita#action#include(names, ...) abort
  for name in a:names
    call call(printf('gita#action#%s#define', name), [get(a:000, 0)])
  endfor
endfunction

function! gita#action#smart_map(lhs, rhs) abort range
  try
    let candidates = gita#action#get_candidates(a:firstline, a:lastline)
    return empty(candidates) ? a:lhs : a:rhs
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction


