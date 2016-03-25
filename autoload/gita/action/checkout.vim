let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! s:action(candidates, options) abort
  let git = gita#core#get_or_fail()
  let options = extend({
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'commitish': '',
        \}, a:options)
  if !options.ours && !options.theirs && empty(options.commitish)
    let commitish = gita#meta#get('commit', '')
  else
    let commitish = options.commitish
  endif
  let args = [
        \ 'checkout',
        \ options.force ? '--force' : '',
        \ options.ours ? '--ours' : '',
        \ options.theirs ? '--theirs' : '',
        \ commitish,
        \]
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 's:Path.unixpath(s:Git.get_relative_path(git, v:val.path))',
        \)
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#util#doautocmd('User', 'GitaStatusModified')
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
        \ 'options': { 'commitish': 'HEAD' },
        \})
  call gita#action#define('checkout:HEAD:force', function('s:action'), {
        \ 'description': 'Checkout a contents from HEAD (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'commitish': 'HEAD', 'force': 1 },
        \})
  call gita#action#define('checkout:origin/HEAD', function('s:action'), {
        \ 'description': 'Checkout a contents from origin/HEAD',
        \ 'requirements': ['path'],
        \ 'options': { 'commitish': 'origin/HEAD' },
        \})
  call gita#action#define('checkout:origin/HEAD:force', function('s:action'), {
        \ 'description': 'Checkout a contents from origin/HEAD (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'commitish': 'origin/HEAD', 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
