let s:save_cpo = &cpo
set cpo&vim

let s:actions = {}
function! s:actions.help(candidates, options) abort " {{{
  call gita#utils#help#toggle(get(a:options, 'name', ''))
  if has_key(self, 'update')
    call self.update(a:candidates, a:options)
  endif
endfunction " }}}
function! s:actions.edit(candidates, options) abort " {{{
  for candidate in a:candidates
    call gita#utils#anchor#focus()
    call gita#features#file#show({
          \ 'commit': 'WORKTREE',
          \ 'file':   get(candidate, 'path2', candidate.path),
          \ 'opener': get(a:options, 'opener', 'edit'),
          \ 'range':  get(a:options, 'range', 'tabpage'),
          \})
  endfor
endfunction " }}}
function! s:actions.open(candidates, options) abort " {{{
  for candidate in a:candidates
    let commit = get(a:options, 'commit', '')
    if empty(commit)
      let commit = candidate.is_unstaged
            \ ? 'INDEX'
            \ : 'HEAD'
    endif
    call gita#utils#anchor#focus()
    call gita#features#file#show({
          \ 'commit': commit,
          \ 'file': candidate.path,
          \ 'opener': get(a:options, 'opener', 'edit'),
          \ 'range':  get(a:options, 'range', 'tabpage'),
          \})
  endfor
endfunction " }}}
function! s:actions.diff(candidates, options) abort " {{{
  for candidate in a:candidates
    let commit = get(a:options, 'commit', '')
    if empty(commit)
      let commit = candidate.is_unstaged
            \ ? 'INDEX'
            \ : 'HEAD'
    endif
    call gita#utils#anchor#focus()
    call gita#features#diff#show({
          \ '--': [candidate.path],
          \ 'commit': commit,
          \ 'split':    get(a:options, 'split', 1),
          \ 'opener':   get(a:options, 'opener', 'edit'),
          \ 'opener2':  get(a:options, 'opener2', 'split'),
          \ 'range':    get(a:options, 'range', 'tabpage'),
          \ 'vertical': get(a:options, 'vertical', 1),
          \})
  endfor
endfunction " }}}

function! gita#action#get_actions() abort " {{{
  let b:_gita_actions = get(b:, '_gita_actions', deepcopy(s:actions))
  return b:_gita_actions
endfunction " }}}
function! gita#action#extend_actions(actions) abort " {{{
  call extend(
        \ gita#action#get_actions(),
        \ a:actions,
        \)
endfunction " }}}
function! gita#action#get_candidates(...) abort " {{{
  let start = get(a:000, 0, 0)
  let end   = get(a:000, 1, -1)
  if has_key(b:, '_gita_action_get_candidates')
    return b:_gita_action_get_candidates(start, end)
  else
    return filter(
          \ get(w:, '_gita_action_candidates', [])[ start : end ],
          \ '!empty(v:val)',
          \)
  endif
endfunction " }}}
function! gita#action#set_candidates(candidates) abort " {{{
  if s:P.is_funcref(a:candidates)
    silent! unlet w:_gita_action_candidates
    let b:_gita_action_get_candidates = a:candidates
  else
    silent! unlet b:_gita_action_get_candidates
    let w:_gita_action_candidates = a:candidates
  endif
endfunction " }}}
function! gita#action#smart_map(lhs, rhs) abort range " {{{
  return empty(gita#action#get_candidates(a:firstline, a:firstline))
        \ ? a:lhs
        \ : a:rhs
endfunction " }}}
function! gita#action#exec(name, ...) abort range " {{{
  let options = extend(
        \ deepcopy(get(w:, '_gita_options', {})),
        \ get(a:000, 0, {}),
        \)
  let candidates = gita#action#get_candidates(
        \ a:firstline, a:lastline,
        \)
  let actions = gita#action#get_actions()
  call call(
        \ actions[a:name],
        \ [candidates, options],
        \ actions,
        \)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
