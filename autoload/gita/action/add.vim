function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let args = [
        \ '--quiet', '--ignore-errors',
        \ options.force ? '--force' : '',
        \]
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 'fnameescape(get(v:val, "path2", v:val.path))',
        \)
  execute printf('Gita add %s', join(args))
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
