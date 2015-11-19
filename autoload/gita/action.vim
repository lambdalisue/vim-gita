let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:P = gita#import('Prelude')
let s:F = gita#import('System.File')

let s:actions = {}
function! s:actions.update(candidates, options, config) abort " {{{
  let winnum = winnr()
  if gita#utils#buffer#focus_group('vim_gita_monitor', { 'keepjumps': 1 })
    if winnr() != winnum
      call gita#action#call('update')
      execute printf('keepjumps %dwincmd w', winnum)
    endif
  endif
endfunction " }}}
function! s:actions.help(candidates, options, config) abort " {{{
  call gita#utils#help#toggle(get(a:options, 'name', ''))
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.open(candidates, options, config) abort " {{{
  call call('gita#features#file#action', [a:candidates, a:options, a:config])
endfunction " }}}
function! s:actions.edit(candidates, options, config) abort " {{{
  let options = extend(a:options, {
        \ 'commit': 'WORKTREE',
        \})
  call call('gita#features#file#action', [a:candidates, options, a:config])
endfunction " }}}
function! s:actions.diff(candidates, options, config) abort " {{{
  call call('gita#features#diff#action', [a:candidates, a:options, a:config])
endfunction " }}}
function! s:actions.conflict(candidates, options, config) abort " {{{
  call call('gita#features#conflict#action', [a:candidates, a:options, a:config])
endfunction " }}}
function! s:actions.blame(candidates, options, config) abort " {{{
  call call('gita#features#blame#action', [a:candidates, a:options, a:config])
endfunction " }}}
function! s:actions.browse(candidates, options, config) abort " {{{
  call call('gita#features#browse#action', [a:candidates, a:options, a:config])
endfunction " }}}
function! s:actions.add(candidates, options, config) abort " {{{
  call call('gita#features#add#action', [a:candidates, a:options, a:config])
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.rm(candidates, options, config) abort " {{{
  call call('gita#features#rm#action', [a:candidates, a:options, a:config])
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.reset(candidates, options, config) abort " {{{
  call call('gita#features#reset#action', [a:candidates, a:options, a:config])
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.checkout(candidates, options, config) abort " {{{
  call call('gita#features#checkout#action', [a:candidates, a:options, a:config])
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.stage(candidates, options, config) abort " {{{
  let add_candidates = []
  let rm_candidates = []
  for candidate in a:candidates
    call gita#utils#status#extend_candidate(candidate)
    if candidate.status.is_unstaged && candidate.status.worktree ==# 'D'
      call add(rm_candidates, candidate)
    else
      call add(add_candidates, candidate)
    endif
  endfor
  call self.add(add_candidates, extend({ 'no_update': 1 }, a:options), a:config)
  call self.rm(rm_candidates, extend({ 'no_update': 1 }, a:options), a:config)
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.unstage(candidates, options, config) abort " {{{
  call self.reset(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.toggle(candidates, options, config) abort " {{{
  let stage_candidates = []
  let reset_candidates = []
  for candidate in a:candidates
    call gita#utils#status#extend_candidate(candidate)
    if candidate.status.is_staged && candidate.status.is_unstaged
      if g:gita#features#status#prefer_unstage_in_toggle
        call add(reset_candidates, candidate)
      else
        call add(stage_candidates, candidate)
      endif
    elseif candidate.status.is_staged
      call add(reset_candidates, candidate)
    elseif candidate.status.is_unstaged || candidate.status.is_untracked || candidate.status.is_ignored
      call add(stage_candidates, candidate)
    endif
  endfor
  call self.stage(stage_candidates, extend({ 'no_update': 1 }, a:options), a:config)
  call self.unstage(reset_candidates, extend({ 'no_update': 1 }, a:options), a:config)
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}
function! s:actions.discard(candidates, options, config) abort " {{{
  let delete_candidates = []
  let checkout_candidates = []
  for candidate in a:candidates
    call gita#utils#status#extend_candidate(candidate)
    if candidate.status.is_conflicted
      call gita#utils#prompt#warn(printf(
            \ 'A conflicted file "%s" cannot be discarded. Resolve the conflict first.',
            \ candidate.path,
            \))
      continue
    elseif candidate.status.is_untracked || candidate.status.is_ignored
      call add(delete_candidates, candidate)
    elseif candidate.status.is_staged || candidate.status.is_unstaged
      call add(checkout_candidates, candidate)
    endif
  endfor
  if get(a:options, 'confirm', 1)
    call gita#utils#prompt#warn(join([
          \ 'A discard action will discard all local changes on the working tree',
          \ 'and the operation is irreversible, mean that you have no chance to',
          \ 'revert the operation.',
          \]))
    if !gita#utils#prompt#asktf('Are you sure you want to discard the changes?')
      call gita#utils#prompt#echo(
            \ 'The operation has canceled by user.'
            \)
      return
    endif
  endif
  " delete untracked files
  for candidate in delete_candidates
    let abspath = get(candidate, 'realpath', candidate.path)
    if isdirectory(abspath)
      silent! call s:F.rmdir(abspath, 'r')
    elseif filewritable(abspath)
      silent! call delete(abspath)
    endif
  endfor
  " checkout tracked files from HEAD
  let options = deepcopy(a:options)
  let options.commit = 'HEAD'
  let options.force = 1
  call self.checkout(checkout_candidates, extend({ 'no_update': 1 }, options), a:config)
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}

function! s:default_get_candidates(start, end, ...) abort " {{{
  let path = gita#utils#path#expand('%')
  let commit = gita#meta#get('commit', '')
  let candidate = gita#action#new_candidate(path, commit, {
        \ 'line_start': a:start,
        \ 'line_end': a:end,
        \})
  return [candidate]
endfunction " }}}
function! gita#action#new_candidate(path, commit, ...) abort " {{{
  let candidate = {
        \ 'path': gita#utils#path#unix_abspath(a:path),
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
function! gita#action#call(name, ...) abort range " {{{
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
  call gita#action#exec(a:name, [a:firstline, a:lastline], options, config)
endfunction " }}}
function! gita#action#exec(name, range, ...) abort " {{{
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
  let candidates = gita#action#get_candidates(
        \ a:range[0], a:range[1], options,
        \)
  let actions = gita#action#get_actions()
  call call(
        \ actions[a:name],
        \ [deepcopy(candidates), deepcopy(options), deepcopy(config)],
        \ actions,
        \)
  call gita#utils#prompt#debug(
        \ printf('action "%s" is called with "%s", "%s"', a:name, string(candidates), string(options)),
        \)
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
