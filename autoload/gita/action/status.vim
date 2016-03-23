function! s:action(candidate, options) abort
  let filenames = gita#meta#get_for(
        \ '^gita-\%(status\|commit\)$', 'filenames', []
        \)
  let args = ['--'] + map(
        \ copy(filenames),
        \ 'fnameescape(v:val)',
        \)
  execute 'Gita status ' . join(filter(args, '!empty(v:val)'))
endfunction

function! gita#action#status#define(disable_mapping) abort
  call gita#action#define('status', function('s:action'), {
        \ 'description': 'Open gita-status window',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
endfunction
