let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#import('Prelude')

function! s:get(name, options, candidate, ...) abort " {{{
  " Note:
  "   Priority options > candidate > meta
  let default = get(a:000, 0, '')
  return get(a:options, a:name, get(a:candidate, a:name, a:default))
endfunction " }}}
let s:actions = {}
function! s:actions.update(candidates, options) abort " {{{
endfunction " }}}
function! s:actions.help(candidates, options) abort " {{{
  call gita#utils#help#toggle(get(a:options, 'name', ''))
  call self.update(a:candidates, a:options)
endfunction " }}}
function! s:actions.open(candidates, options) abort " {{{
  call call('gita#features#file#action', [a:candidates, a:options])
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  call gita#utils#anchor#focus()
  call gita#features#file#show({
        \ 'file': s:get('path', a:options, candidate),
        \ 'commit': s:get('commit', a:options, candidate),
        \ 'line_start': s:get('line_start', a:options, candidate, 0),
        \ 'line_end': s:get('line_end', a:options, candidates, 0),
        \ 'opener': get(a:options, 'opener', 'edit'),
        \ 'range':  get(a:options, 'range', 'tabpage'),
        \})
endfunction " }}}
function! s:actions.edit(candidates, options) abort " {{{
  let options = extend(a:options, {
        \ 'commit': 'WORKTREE',
        \})
  call call('gita#features#file#action', [a:candidates, options])
endfunction " }}}
function! s:actions.diff(candidates, options) abort " {{{
  call call('gita#features#diff#action', [a:candidates, a:options])
endfunction " }}}
function! s:actions.add(candidates, options) abort " {{{
  call call('gita#features#add#action', [a:candidates, a:options])
  call self.update(a:candidates, a:options)
endfunction " }}}
function! s:actions.rm(candidates, options) abort " {{{
  call call('gita#features#rm#action', [a:candidates, a:options])
  call self.update(a:candidates, a:options)
endfunction " }}}
function! s:actions.reset(candidates, options) abort " {{{
  call call('gita#features#reset#action', [a:candidates, a:options])
  call self.update(a:candidates, a:options)
endfunction " }}}
function! s:actions.checkout(candidates, options) abort " {{{
  call call('gita#features#checkout#action', [a:candidates, a:options])
  call self.update(a:candidates, a:options)
endfunction " }}}
function! s:actions.solve(candidates, options) abort " {{{
  call call('gita#features#conflict#action', [a:candidates, a:options])
  call self.update(a:candidates, a:options)
endfunction " }}}

function! s:default_get_candidates(start, end, ...) abort " {{{
  let path = gita#utils#expand('%')
  let commit = gita#meta#get('commit', '')
  let candidate = gita#action#new_candidate(path, commit, {
        \ 'line_start': a:start,
        \ 'line_end': a:end,
        \})
  return [candidate]
endfunction " }}}
function! gita#action#new_candidate(path, commit, ...) abort " {{{
  let candidate = {
        \ 'path': gita#utils#ensure_abspath(a:path),
        \ 'commit': a:commit,
        \}
  return extend(candidate, get(a:000, 0, {}))
endfunction " }}}
function! gita#action#get_actions() abort " {{{
  return get(b:, '_gita_actions', s:actions)
endfunction " }}}
function! gita#action#extend_actions(actions) abort " {{{
  let b:_gita_actions = extend(
        \ deepcopy(gita#action#get_actions()),
        \ a:actions
        \)
endfunction " }}}
function! gita#action#get_candidates(...) abort " {{{
  let start = get(a:000, 0, 0)
  let end = get(a:000, 1, -1)
  let options = get(a:000, 2, {})
  if has_key(b:, '_gita_action_get_candidates')
    return b:_gita_action_get_candidates(start, end, options)
  else
    return s:default_get_candidates(start, end, options)
  endif
endfunction " }}}
function! gita#action#register_get_candidates(get_candidates) abort " {{{
  let b:_gita_action_get_candidates = a:get_candidates
endfunction " }}}
function! gita#action#smart_map(lhs, rhs) abort range " {{{
  return empty(gita#action#get_candidates(a:firstline, a:firstline))
        \ ? a:lhs
        \ : a:rhs
endfunction " }}}
function! gita#action#exec(name, ...) abort range " {{{
  let options = get(a:000, 0, {})
  let candidates = gita#action#get_candidates(
        \ a:firstline, a:lastline, options,
        \)
  let actions = gita#action#get_actions()
  call call(
        \ actions[a:name],
        \ [deepcopy(candidates), deepcopy(options)],
        \ actions,
        \)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
