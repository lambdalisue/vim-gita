function! s:action(candidates, options) abort
  let args = ['--'] + map(
        \ copy(a:candidates),
        \ 'fnameescape(v:val.path)',
        \)
  execute 'Gita reset --quiet ' . join(args)
endfunction

function! gita#action#reset#define(disable_mappings) abort
  call gita#action#define('reset', function('s:action'), {
        \ 'description': 'Reset changes on the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
endfunction
