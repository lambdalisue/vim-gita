function! s:action(candidates, options) abort
  let options = extend({
        \ 'no-ff': 0,
        \ 'ff-only': 0,
        \ 'squash': 0,
        \}, a:options)
  let args = [
        \ 'merge',
        \ '--no-edit',
        \ '--verbose',
        \ options['no-ff'] ? '--no-ff' : '',
        \ options['ff-only'] ? '--ff-only' : '',
        \ options.squash ? '--squash' : '',
        \ '--',
        \] + map(
        \ copy(a:candidates),
        \ 'v:val.name',
        \)
  let args = filter(args, '!empty(v:val)')
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! gita#action#merge#define(disable_mapping) abort
  call gita#action#define('merge', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (fast-forward)',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('merge:ff-only', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (fast-forward only)',
        \ 'requirements': ['name'],
        \ 'options': { 'ff-only': 1 },
        \})
  call gita#action#define('merge:no-ff', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (no fast-foward)',
        \ 'requirements': ['name'],
        \ 'options': { 'no-ff': 1 },
        \})
  call gita#action#define('merge:squash', function('s:action'), {
        \ 'description': 'Merge the commit into HEAD (squash)',
        \ 'requirements': ['name'],
        \ 'options': { 'squash': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
