function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \ 'cached': 0,
        \}, a:options)
  let git = gita#core#get_or_fail()
  let args = [
        \ 'rm',
        \ '--ignore-unmatch',
        \ options.cached ? '--cached' : '',
        \ options.force ? '--force' : '',
        \ '--',
        \] + map(
        \ copy(a:candidates),
        \ 'gita#normalize#abspath(git, get(v:val, ''path2'', v:val.path))',
        \)
  let args = filter(args, '!empty(v:val)')
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#trigger_modified()
endfunction

function! gita#action#rm#define(disable_mappings) abort
  call gita#action#define('rm', function('s:action'), {
        \ 'description': 'Remove files from the working tree and from the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('rm:cached', function('s:action'), {
        \ 'description': 'Remove files from the index but the working tree',
        \ 'requirements': ['path'],
        \ 'options': { 'cached': 1 },
        \})
  call gita#action#define('rm:force', function('s:action'), {
        \ 'description': 'Remove files from the working tree and from the index (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
