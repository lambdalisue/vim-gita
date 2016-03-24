function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let args = [
        \ 'add',
        \ '--ignore-errors',
        \ options.force ? '--force' : '',
        \]
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 'get(v:val, ''path2'', v:val.path)',
        \)
  call gita#execute(args, { 'quiet': 1 })
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#action#add#define(disable_mappings) abort
  call gita#action#define('add', function('s:action'), {
        \ 'description': 'Add file contents to the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('add:force', function('s:action'), {
        \ 'description': 'Add file contents to the index (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
