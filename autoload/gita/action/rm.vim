function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let args = options.force ? ['--force'] : []
  let args += ['--'] + map(
        \ copy(a:candidates),
        \ 'fnameescape(get(v:val, "path2", v:val.path))',
        \)
  execute 'Gita rm --quiet ' . join(args)
endfunction

function! gita#action#rm#define(disable_mappings) abort
  call gita#action#define('rm', function('s:action'), {
        \ 'description': 'Remove files from the working tree and from the index',
        \ 'requirements': ['path'],
        \ 'options': {},
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
