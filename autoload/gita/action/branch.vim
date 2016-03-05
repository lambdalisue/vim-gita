function! s:action_checkout(candidate, options) abort
  let options = extend({
        \ 'force': 0,
        \ 'no-track': 0,
        \}, a:options)
  call gita#command#checkout#call({
        \ 'force': options.force,
        \ 'no-track': options['no-track'],
        \ 'commit': a:candidate.name,
        \})
endfunction

function! gita#action#branch#define(disable_mapping) abort
  call gita#action#define('branch:checkout', function('s:action_checkout'), {
        \ 'description': 'Checkout a branch',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': {},
        \})
  call gita#action#define('branch:checkout:no-track', function('s:action_checkout'), {
        \ 'description': 'Checkout a branch (no-tracking)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['name'],
        \ 'options': { 'no-track': 1 },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer> ct <Plug>(gita-branch-checkout)
  nmap <buffer> cn <Plug>(gita-branch-checkout-no-track)
endfunction

