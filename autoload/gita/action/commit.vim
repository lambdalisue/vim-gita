function! s:action_open(candidate, options) abort
  let filenames = gita#meta#get_for(
        \ '^gita-\%(status\|commit\)$', 'filenames', []
        \)
  let options = extend({
        \ 'amend': 0,
        \}, a:options)
  call gita#content#commit#open({
        \ 'amend': options.amend,
        \ 'filenames': filenames,
        \})
endfunction

function! gita#action#commit#define(disable_mapping) abort
  call gita#action#define('commit', function('s:action_open'), {
        \ 'description': 'Open gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('commit:amend', function('s:action_open'), {
        \ 'description': 'Open an AMEND gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': { 'amend': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
