function! s:is_available(candidate) abort
  let necessary_attributes = [
      \ 'is_remote',
      \ 'is_selected',
      \ 'name',
      \ 'remote',
      \ 'linkto',
      \ 'record',
      \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:action(candidates, options) abort
  let options = extend({
        \ 'no-ff': 0,
        \ 'ff-only': 0,
        \ 'squash': 0,
        \}, a:options)
  let branch_names = []
  for candidate in a:candidates
    if s:is_available(candidate)
      call add(branch_names, candidate.name)
    endif
  endfor
  if empty(branch_names)
    return
  endif
  call gita#command#merge#call({
        \ 'commits': branch_names,
        \ 'no-ff': options['no-ff'],
        \ 'ff-only': options['ff-only'],
        \ 'squash': options.squash,
        \})
endfunction

function! gita#action#merge#define(disable_mapping) abort
  call gita#action#define('merge', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (fast-forward)',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('merge:ff-only', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (fast-forward only)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'ff-only': 1 },
        \})
  call gita#action#define('merge:no-ff', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (no fast-foward)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'no-ff': 1 },
        \})
  call gita#action#define('merge:squash', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (squash)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'squash': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
