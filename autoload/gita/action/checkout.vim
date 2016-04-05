let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'commit': '',
        \}, a:options)
  let git = gita#core#get_or_fail()
  let args = [
        \ 'checkout',
        \ options.force ? '--force' : '',
        \ options.ours ? '--ours' : '',
        \ options.theirs ? '--theirs' : '',
        \ gita#normalize#commit(git, options.commit),
        \ '--',
        \] + map(
        \ copy(a:candidates),
        \ 'gita#normalize#relpath(git, v:val.path)',
        \)
  let args = filter(args, '!empty(v:val)')
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#trigger_modified()
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
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'ours': 1, 'force': 1 },
        \})
  call gita#action#define('checkout:theirs', function('s:action'), {
        \ 'description': 'Checkout a contents',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'theirs': 1 },
        \})
  call gita#action#define('checkout:theirs:force', function('s:action'), {
        \ 'description': 'Checkout a contents (force)',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'theirs': 1, 'force': 1 },
        \})
  call gita#action#define('checkout:HEAD', function('s:action'), {
        \ 'description': 'Checkout a contents from HEAD',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'commit': 'HEAD' },
        \})
  call gita#action#define('checkout:HEAD:force', function('s:action'), {
        \ 'description': 'Checkout a contents from HEAD (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'commit': 'HEAD', 'force': 1 },
        \})
  call gita#action#define('checkout:origin/HEAD', function('s:action'), {
        \ 'description': 'Checkout a contents from origin/HEAD',
        \ 'requirements': ['path'],
        \ 'options': { 'commit': 'origin/HEAD' },
        \})
  call gita#action#define('checkout:origin/HEAD:force', function('s:action'), {
        \ 'description': 'Checkout a contents from origin/HEAD (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'commit': 'origin/HEAD', 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
