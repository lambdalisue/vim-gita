function! s:action(candidates, options) abort
  let options = extend({
        \ 'no-ff': 0,
        \ 'ff-only': 0,
        \ 'squash': 0,
        \}, a:options)
  let args = [
        \ empty(options['no-ff']) ? '' : '--no-ff',
        \ empty(options['ff-only']) ? '' : '--ff-only',
        \ empty(options.squash) ? '' : '--squash',
        \]
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 'shellescape(v:val.name)',
        \)
  execute 'Gita merge ' . join(filter(args, '!empty(v:val)'))
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
