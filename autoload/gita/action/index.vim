function! s:is_available_for_stage(candidate) abort
  let necessary_attributes = ['path', 'is_unstaged', 'worktree']
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:is_available_for_toggle(candidate) abort
  let necessary_attributes = [
        \ 'path', 'is_staged', 'is_unstaged',
        \ 'is_untracked', 'is_ignored',
        \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:action_stage(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let rm_candidates = []
  let add_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available_for_stage(v:val)')
  for candidate in candidates
    if candidate.is_unstaged && candidate.worktree ==# 'D'
      call add(rm_candidates, candidate)
    else
      call add(add_candidates, candidate)
    endif
  endfor
  noautocmd call gita#action#do('add', add_candidates)
  noautocmd call gita#action#do('rm', rm_candidates)
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! s:action_unstage(candidates, options) abort
  call gita#action#do('reset', a:candidates)
endfunction

function! s:action_toggle(candidates, options) abort
  let options = copy(a:options)
  let stage_candidates = []
  let unstage_candidates = []
  let candidates = filter(copy(a:candidates), 's:is_available_for_toggle(v:val)')
  for candidate in candidates
    if candidate.is_staged && candidate.is_unstaged
      if g:gita#action#toggle#prefer_unstage
        call add(unstage_candidates, candidate)
      else
        call add(stage_candidates, candidate)
      endif
    elseif candidate.is_staged
      call add(unstage_candidates, candidate)
    elseif candidate.is_unstaged || candidate.is_untracked || candidate.is_ignored
      call add(stage_candidates, candidate)
    endif
  endfor
  noautocmd call gita#action#do('index:stage', stage_candidates)
  noautocmd call gita#action#do('index:unstage', unstage_candidates)
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#action#index#define(disable_mapping) abort
  call gita#action#define('stage', function('s:action_stage'), {
        \ 'description': 'Stage changes to the index',
        \ 'options': {},
        \})
  call gita#action#define('unstage', function('s:action_unstage'), {
        \ 'description': 'Unstage changes from the index',
        \ 'options': {},
        \})
  call gita#action#define('toggle', function('s:action_toggle'), {
        \ 'description': 'Toggle stage/unstage of changes in the index',
        \ 'options': {},
        \})
  call gita#action#add#define(0)
  call gita#action#rm#define(0)
  call gita#action#reset#define(0)
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> << gita#action#smart_map('<<', '<Plug>(gita-stage)')
  nmap <buffer><nowait><expr> >> gita#action#smart_map('>>', '<Plug>(gita-unstage)')
  nmap <buffer><nowait><expr> -- gita#action#smart_map('--', '<Plug>(gita-toggle)')
  vmap <buffer><nowait><expr> << gita#action#smart_map('<<', '<Plug>(gita-stage)')
  vmap <buffer><nowait><expr> >> gita#action#smart_map('>>', '<Plug>(gita-unstage)')
  vmap <buffer><nowait><expr> -- gita#action#smart_map('--', '<Plug>(gita-toggle)')
endfunction

call gita#util#define_variables('action#index', {
      \ 'prefer_unstage': 0,
      \})
