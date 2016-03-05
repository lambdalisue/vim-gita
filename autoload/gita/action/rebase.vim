function! s:action(candidates, options) abort
  let options = extend({
        \ 'merge': 0,
        \}, a:options)
  let branch_names = map(copy(a:candidates), 'v:val.name')
  call gita#command#rebase#call({
        \ 'quiet': 0,
        \ 'commits': branch_names,
        \ 'merge': options.merge,
        \})
endfunction

function! gita#action#rebase#define(disable_mapping) abort
  call gita#action#define('rebase', function('s:action'), {
        \ 'description': 'Rebase HEAD from the commit (fast-forward)',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('rebase:merge', function('s:action'), {
        \ 'description': 'Rebase HEAD by merging the commit',
        \ 'requirements': ['name'],
        \ 'options': { 'merge': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
