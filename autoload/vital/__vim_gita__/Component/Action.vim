let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:_vital_created(module) abort
  let s:actionbooks = {}
  let s:config = {
        \ 'mapping_prefix': 'vital-component-action-',
        \}
endfunction

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Guard = a:V.import('Vim.Guard')
endfunction

function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Vim.Guard',
        \]
endfunction

function! s:_throw(msg) abort
  throw 'vital: Component.Action: ' . a:msg
endfunction

function! s:_get_candidates_default(startline, endline) abort
  let candidates = {}
  let candidates = map(
        \ getline(a:startline, a:endline),
        \ 'extend(candidates, { ''record'': v:val })',
        \)
  return candidates
endfunction

function! s:is_attached() abort
  return exists('b:_vital_component_action_book')
endfunction

function! s:is_satisfied(candidate, action) abort
  for requirement in a:action.requirements
    if !has_key(a:candidate, requirement)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:attach(...) abort
  let Funcref = get(a:000, 0, '')
  let Funcref = s:Prelude.is_string(Funcref)
        \ ? function(empty(Funcref) ? 's:_get_candidates_default' : Funcref)
        \ : Funcref
  let b:_vital_component_action_book = {
        \ 'get_candidates': Funcref,
        \ 'actions': {},
        \ 'aliases': {},
        \}
  return b:_vital_component_action_book
endfunction

function! s:get_book() abort
  if !s:is_attached()
    call s:_throw(printf(
          \ 'No action book has attached on a current buffer "%s"',
          \ bufname('%'),
          \))
  endif
  return b:_vital_component_action_book
endfunction

function! s:get_action(name) abort
  let book = s:get_book()
  if !has_key(book.actions, a:name) && !has_key(book.aliases, a:name)
    call s:_throw(printf(
          \ 'No action "%s" is defined on a current buffer "%s"',
          \ a:name, bufname('%'),
          \))
  endif
  return book.actions[book.aliases[a:name]]
endfunction

function! s:get_candidates(...) abort
  let sl = get(a:000, 0, line('.'))
  let el = get(a:000, 1, sl)
  let book = s:get_book()
  let candidates = filter(
        \ copy(book.get_candidates(sl, el)),
        \ '!empty(v:val)'
        \)
  return candidates
endfunction

function! s:call(name, ...) abort range
  let action = s:get_action(a:name)
  let candidates = get(a:000, 0, {})
  let candidates = empty(candidates)
        \ ? s:get_candidates(a:firstline, a:lastline)
        \ : candidates
  let candidates = filter(
        \ copy(candidates),
        \ 's:is_satisfied(v:val, action)'
        \)
  if !empty(action.requirements) && empty(candidates)
    return
  endif
  if action.mapping_mode =~# '[vx]'
    call call(action.funcref, [candidates, action.options])
  else
    call call(action.funcref, [get(candidates, 0, {}), action.options])
  endif
endfunction

function! s:define(name, funcref, ...) abort
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
        \ ? printf('<Plug>(%s%s)',
        \   s:config.mapping_prefix,
        \   substitute(options.alias, ':', '-', 'g')
        \ )
        \ : options.mapping
  let action_holder = gita#action#get_holder()
  let action_holder.aliases[options.alias] = a:name
  let action_holder.actions[a:name] = {
        \ 'funcref': s:Prelude.is_funcref(a:funcref)
        \   ? a:funcref
        \   : function(a:funcref),
        \ 'alias': options.alias,
        \ 'description': description,
        \ 'mapping': mapping,
        \ 'mapping_mode': options.mapping_mode,
        \ 'requirements': options.requirements,
        \ 'options': options.options,
        \}
  for mode in split(options.mapping_mode, '\zs')
    execute printf(
          \ '%snoremap <buffer><silent> %s :%scall <SID>call("%s")<CR>',
          \ mode, mapping, mode ==# '[ni]' ? '<C-u>' : '', a:name,
          \)
  endfor
endfunction

function! s:smart_map(lhs, rhs) abort range
  try
    let candidates = s:get_candidates(a:firstline, a:lastline)
    return empty(candidates) ? a:lhs : a:rhs
  catch /^vital: UI.Action:/
    return a:lhs
  endtry
endfunction

function! s:find_mappings(book) abort
  let guard = s:Guard.store('&verbose', '&verbosefile')
  try
    set verbose=0 verbosefile=
    redir => content
    silent execute 'map'
  finally
    redir END
    call guard.restore()
  endtry

  let rhss = filter(
        \ map(values(a:book.actions), 'v:val.mapping'),
        \ '!empty(v:val)'
        \)
  let rhsp = '\%(' . join(map(rhss, 'escape(v:val, ''\'')'), '\|') . '\)'
  let rows = filter(
        \ split(content, '\r\?\n'),
        \ 'v:val =~# ''@.*'' . rhsp'
        \)
  let pattern = '\(...\)\(\S\+\)'
  let mappings = {}
  for row in rows
    let [mode, lhs] = matchlist(row, pattern)[1 : 2]
    let rhs = matchstr(row, rhsp)
    let mappings[rhs] = {
          \ 'mode': mode,
          \ 'lhs': lhs,
          \ 'rhs': rhs,
          \}
  endfor
  return mappings
endfunction

function! s:select_action(candidates, ...) abort
  let options = extend({
        \ 'prefix': 'action: ',
        \ 'default': '',
        \}, get(a:000, 0, {}))
  let book = s:get_book()
  let g:_vital_component_action_candidates = join(keys(book.aliases), "\n")
  call inputsave()
  try
    echohl Question
    redraw | echo
    let alias = input(
          \ options.prefix,
          \ options.default,
          \ 'custom,VitalComponentActionComplete',
          \)
    redraw | echo
  finally
    echohl None
    call inputrestore()
    unlet g:_vital_component_action_candidates
  endtry
  if empty(alias)
    return
  endif
  call s:call(alias, a:candidates)
endfunction

function! VitalComponentActionComplete(arglead, cmdline, cursorpos) abort
  " NOTE: return value requires to be a string
  return g:_vital_component_action_candidates
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
