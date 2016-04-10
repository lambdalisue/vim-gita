function! s:action_stage(candidates, options) abort
  let rm_candidates = []
  let add_candidates = []
  for candidate in a:candidates
    if candidate.is_unstaged && candidate.worktree ==# 'D'
      call add(rm_candidates, candidate)
    else
      call add(add_candidates, candidate)
    endif
  endfor
  noautocmd call gita#action#call('add', add_candidates)
  noautocmd call gita#action#call('rm', rm_candidates)
  call gita#trigger_modified()
endfunction

function! s:action_unstage(candidates, options) abort
  call gita#action#call('reset', a:candidates)
endfunction

function! s:action_toggle(candidates, options) abort
  let stage_candidates = []
  let unstage_candidates = []
  for candidate in a:candidates
    if candidate.is_staged && candidate.is_unstaged
      if g:gita#action#index#prefer_unstage
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
  noautocmd call gita#action#call('index:stage', stage_candidates)
  noautocmd call gita#action#call('index:unstage', unstage_candidates)
  call gita#trigger_modified()
endfunction

function! gita#action#index#define(disable_mapping) abort
  " include dependencies without default mappings
  call gita#action#include(['add', 'rm', 'reset'], 1)
  call gita#action#define('index:stage', function('s:action_stage'), {
        \ 'alias': 'stage',
        \ 'description': 'Stage changes to the index',
        \ 'requirements': [
        \   'path',
        \   'is_unstaged',
        \   'worktree',
        \ ],
        \ 'options': {},
        \})
  call gita#action#define('index:unstage', function('s:action_unstage'), {
        \ 'alias': 'unstage',
        \ 'description': 'Unstage changes from the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('index:toggle', function('s:action_toggle'), {
        \ 'alias': 'toggle',
        \ 'description': 'Toggle stage/unstage of changes in the index',
        \ 'requirements': [
        \   'path',
        \   'is_staged',
        \   'is_unstaged',
        \   'is_untracked',
        \   'is_ignored',
        \   'worktree',
        \ ],
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> << gita#action#smart_map('<<', '<Plug>(gita-index-stage)')
  nmap <buffer><nowait><expr> >> gita#action#smart_map('>>', '<Plug>(gita-index-unstage)')
  nmap <buffer><nowait><expr> -- gita#action#smart_map('--', '<Plug>(gita-index-toggle)')
  vmap <buffer><nowait><expr> << gita#action#smart_map('<<', '<Plug>(gita-index-stage)')
  vmap <buffer><nowait><expr> >> gita#action#smart_map('>>', '<Plug>(gita-index-unstage)')
  vmap <buffer><nowait><expr> -- gita#action#smart_map('--', '<Plug>(gita-index-toggle)')
endfunction

call gita#define_variables('action#index', {
      \ 'prefer_unstage': 0,
      \})
