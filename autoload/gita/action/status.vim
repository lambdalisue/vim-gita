function! s:action(candidate, options) abort
  let filenames = gita#meta#get('filenames', [])
  call gita#ui#status#open({
        \ 'filenames': filenames,
        \})
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
