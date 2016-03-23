function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \}, a:options)
  call gita#option#assign_commit(options)
  let args = [
        \ empty(options.force) ? '' : '--force',
        \ empty(options.ours) ? '' : '--ours',
        \ empty(options.theirs) ? '' : '--theirs',
        \ get(a:options, 'commit', ''),
        \]
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 'fnameescape(v:val.path)',
        \)
  execute 'Gita checkout --quiet ' . join(filter(args, '!empty(v:val)'))
endfunction

function! gita#action#checkout#define(disable_mappings) abort
  call gita#action#define('checkout', function('s:action'), {
        \ 'description': 'Checkout a contents',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('checkout:force', function('s:action'), {
        \ 'description': 'Checkout a contents (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'force': 1 },
        \})
  call gita#action#define('checkout:ours', function('s:action'), {
        \ 'description': 'Checkout a contents',
        \ 'requirements': ['path'],
        \ 'options': { 'ours': 1 },
        \})
  call gita#action#define('checkout:ours:force', function('s:action'), {
        \ 'description': 'Checkout a contents (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'ours': 1, 'force': 1 },
        \})
  call gita#action#define('checkout:theirs', function('s:action'), {
        \ 'description': 'Checkout a contents',
        \ 'requirements': ['path'],
        \ 'options': { 'theirs': 1 },
        \})
  call gita#action#define('checkout:theirs:force', function('s:action'), {
        \ 'description': 'Checkout a contents (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'theirs': 1, 'force': 1 },
        \})
  call gita#action#define('checkout:HEAD', function('s:action'), {
        \ 'description': 'Checkout a contents from HEAD',
        \ 'requirements': ['path'],
        \ 'options': { 'commit': 'HEAD' },
        \})
  call gita#action#define('checkout:HEAD:force', function('s:action'), {
        \ 'description': 'Checkout a contents from HEAD (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'commit': 'HEAD', 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> -c gita#action#smart_map('-c', '<Plug>(gita-checkout)')
  nmap <buffer><nowait><expr> -C gita#action#smart_map('-C', '<Plug>(gita-checkout-force)')
  vmap <buffer><nowait><expr> -c gita#action#smart_map('-c', '<Plug>(gita-checkout)')
  vmap <buffer><nowait><expr> -C gita#action#smart_map('-C', '<Plug>(gita-checkout-force)')
endfunction
